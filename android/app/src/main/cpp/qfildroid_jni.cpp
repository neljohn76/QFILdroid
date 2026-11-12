#include <android/log.h>
#include <jni.h>

#include <cstring>
#include <string>
#include <vector>

#include "firehose.h"
#include "sahara.h"
#include "usb_transport.h"

#define LOG_TAG "qfildroid_engine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace {

constexpr char kEngineVersion[] = "0.1.0";

/**
 * IUsbTransport implementation that forwards bulk transfers to the Kotlin
 * NativeUsbBridge object through JNI (which delegates to UsbHostManager).
 */
class JniUsbTransport : public qfildroid::IUsbTransport {
 public:
  JniUsbTransport(JNIEnv* env, const std::string& device_key)
      : env_(env), device_key_(device_key) {
    jclass local = env->FindClass("com/qfildroid/app/protocol/NativeUsbBridge");
    if (local != nullptr) {
      bridge_class_ = static_cast<jclass>(env->NewGlobalRef(local));
      env->DeleteLocalRef(local);
    }
    if (bridge_class_ != nullptr) {
      read_method_ = env->GetStaticMethodID(
          bridge_class_, "bulkRead", "(Ljava/lang/String;II)[B");
      write_method_ = env->GetStaticMethodID(
          bridge_class_, "bulkWrite", "(Ljava/lang/String;[BI)I");
    }
  }

  ~JniUsbTransport() override {
    if (bridge_class_ != nullptr) {
      env_->DeleteGlobalRef(bridge_class_);
      bridge_class_ = nullptr;
    }
  }

  bool Valid() const { return bridge_class_ != nullptr && read_method_ != nullptr &&
                               write_method_ != nullptr; }

  int Write(const uint8_t* data, size_t len, int timeout_ms) override {
    if (!Valid()) return -3;
    jbyteArray array = env_->NewByteArray(static_cast<jsize>(len));
    if (array == nullptr) return -4;
    env_->SetByteArrayRegion(array, 0, static_cast<jsize>(len),
                             reinterpret_cast<const jbyte*>(data));
    jint result = env_->CallStaticIntMethod(bridge_class_, write_method_,
                                            env_->NewStringUTF(device_key_.c_str()),
                                            array, timeout_ms);
    env_->DeleteLocalRef(array);
    if (env_->ExceptionCheck()) {
      env_->ExceptionDescribe();
      env_->ExceptionClear();
      last_error_ = "JNI exception during bulkWrite";
      return -5;
    }
    return result;
  }

  int Read(uint8_t* buffer, size_t max_len, int timeout_ms) override {
    if (!Valid()) return -3;
    jobject result = env_->CallStaticObjectMethod(
        bridge_class_, read_method_, env_->NewStringUTF(device_key_.c_str()),
        static_cast<jint>(max_len), timeout_ms);
    if (env_->ExceptionCheck()) {
      env_->ExceptionDescribe();
      env_->ExceptionClear();
      last_error_ = "JNI exception during bulkRead";
      return -5;
    }
    if (result == nullptr) return -1;
    jsize len = env_->GetArrayLength(static_cast<jbyteArray>(result));
    if (len > 0) {
      env_->GetByteArrayRegion(static_cast<jbyteArray>(result), 0, len,
                               reinterpret_cast<jbyte*>(buffer));
    }
    env_->DeleteLocalRef(result);
    return len;
  }

  const std::string& LastError() const override { return last_error_; }

 private:
  JNIEnv* env_;
  std::string device_key_;
  jclass bridge_class_ = nullptr;
  jmethodID read_method_ = nullptr;
  jmethodID write_method_ = nullptr;
  std::string last_error_ = "JNI bridge unavailable";
};

void PutMapEntry(JNIEnv* env, jobject map, const char* key, jobject value) {
  jclass map_class = env->GetObjectClass(map);
  jmethodID put = env->GetMethodID(
      map_class, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  env->CallObjectMethod(map, put, env->NewStringUTF(key), value);
  env->DeleteLocalRef(map_class);
}

void PutMapEntry(JNIEnv* env, jobject map, const char* key, const char* value) {
  PutMapEntry(env, map, key, env->NewStringUTF(value));
}

jobject NewResultMap(JNIEnv* env) {
  jclass cls = env->FindClass("java/util/HashMap");
  jmethodID ctor = env->GetMethodID(cls, "<init>", "()V");
  jobject map = env->NewObject(cls, ctor);
  env->DeleteLocalRef(cls);
  return map;
}

jobject BooleanBox(JNIEnv* env, bool value) {
  jclass cls = env->FindClass("java/lang/Boolean");
  jmethodID method = env->GetStaticMethodID(cls, "valueOf", "(Z)Ljava/lang/Boolean;");
  jobject boxed = env->CallStaticObjectMethod(cls, method, value ? JNI_TRUE : JNI_FALSE);
  env->DeleteLocalRef(cls);
  return boxed;
}

jobject IntBox(JNIEnv* env, jint value) {
  jclass cls = env->FindClass("java/lang/Integer");
  jmethodID method = env->GetStaticMethodID(cls, "valueOf", "(I)Ljava/lang/Integer;");
  jobject boxed = env->CallStaticObjectMethod(cls, method, value);
  env->DeleteLocalRef(cls);
  return boxed;
}

jobject LongBox(JNIEnv* env, jlong value) {
  jclass cls = env->FindClass("java/lang/Long");
  jmethodID method = env->GetStaticMethodID(cls, "valueOf", "(J)Ljava/lang/Long;");
  jobject boxed = env->CallStaticObjectMethod(cls, method, value);
  env->DeleteLocalRef(cls);
  return boxed;
}

}  // namespace

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_engineVersion(JNIEnv* env,
                                                             jobject /*thiz*/) {
  return env->NewStringUTF(kEngineVersion);
}

JNIEXPORT jobject JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_saharaHandshake(
    JNIEnv* env, jobject /*thiz*/, jstring device_key, jint timeout_ms) {
  jobject map = NewResultMap(env);
  const char* key = env->GetStringUTFChars(device_key, nullptr);
  JniUsbTransport transport(env, key);
  env->ReleaseStringUTFChars(device_key, key);

  if (!transport.Valid()) {
    PutMapEntry(env, map, "ok", BooleanBox(env, false));
    PutMapEntry(env, map, "error", "native USB bridge unavailable");
    return map;
  }

  qfildroid::sahara::SaharaEngine engine(transport);
  qfildroid::sahara::HandshakeResult result;
  engine.Handshake(result, timeout_ms);

  PutMapEntry(env, map, "ok", BooleanBox(env, result.ok));
  PutMapEntry(env, map, "version", IntBox(env, static_cast<jint>(result.device_hello.version)));
  PutMapEntry(env, map, "versionSupported", IntBox(env, static_cast<jint>(result.device_hello.version_supported)));
  PutMapEntry(env, map, "maxCommandLen", IntBox(env, static_cast<jint>(result.device_hello.max_command_len)));
  PutMapEntry(env, map, "error", env->NewStringUTF(result.error.c_str()));
  return map;
}

JNIEXPORT jobject JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_saharaWriteImage(
    JNIEnv* env, jobject /*thiz*/, jstring device_key, jint image_id,
    jbyteArray data, jint timeout_ms) {
  jobject map = NewResultMap(env);
  const char* key = env->GetStringUTFChars(device_key, nullptr);
  JniUsbTransport transport(env, key);
  env->ReleaseStringUTFChars(device_key, key);

  if (!transport.Valid()) {
    PutMapEntry(env, map, "ok", BooleanBox(env, false));
    PutMapEntry(env, map, "error", "native USB bridge unavailable");
    return map;
  }

  jsize len = env->GetArrayLength(data);
  std::vector<uint8_t> buffer(static_cast<size_t>(len));
  if (len > 0) {
    env->GetByteArrayRegion(data, 0, len,
                            reinterpret_cast<jbyte*>(buffer.data()));
  }

  qfildroid::sahara::SaharaEngine engine(transport);
  qfildroid::sahara::WriteResult result;
  engine.WriteImage(static_cast<uint32_t>(image_id), buffer.data(),
                    buffer.size(), qfildroid::sahara::ProgressCallback(),
                    timeout_ms, result);

  PutMapEntry(env, map, "ok", BooleanBox(env, result.ok));
  PutMapEntry(env, map, "imageId", IntBox(env, image_id));
  PutMapEntry(env, map, "bytesSent", LongBox(env, static_cast<jlong>(result.bytes_sent)));
  PutMapEntry(env, map, "status", IntBox(env, static_cast<jint>(result.end_image_tx_status)));
  PutMapEntry(env, map, "error", env->NewStringUTF(result.error.c_str()));
  return map;
}

JNIEXPORT jobject JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_saharaDone(
    JNIEnv* env, jobject /*thiz*/, jstring device_key, jint timeout_ms) {
  jobject map = NewResultMap(env);
  const char* key = env->GetStringUTFChars(device_key, nullptr);
  JniUsbTransport transport(env, key);
  env->ReleaseStringUTFChars(device_key, key);

  if (!transport.Valid()) {
    PutMapEntry(env, map, "ok", BooleanBox(env, false));
    PutMapEntry(env, map, "error", "native USB bridge unavailable");
    return map;
  }

  qfildroid::sahara::SaharaEngine engine(transport);
  qfildroid::sahara::DoneResult result;
  engine.Done(timeout_ms, result);

  PutMapEntry(env, map, "ok", BooleanBox(env, result.ok));
  PutMapEntry(env, map, "status", IntBox(env, static_cast<jint>(result.status)));
  PutMapEntry(env, map, "error", env->NewStringUTF(result.error.c_str()));
  return map;
}

JNIEXPORT jobject JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_saharaReset(
    JNIEnv* env, jobject /*thiz*/, jstring device_key, jint timeout_ms) {
  jobject map = NewResultMap(env);
  const char* key = env->GetStringUTFChars(device_key, nullptr);
  JniUsbTransport transport(env, key);
  env->ReleaseStringUTFChars(device_key, key);

  if (!transport.Valid()) {
    PutMapEntry(env, map, "ok", BooleanBox(env, false));
    PutMapEntry(env, map, "error", "native USB bridge unavailable");
    return map;
  }

  qfildroid::sahara::SaharaEngine engine(transport);
  std::string error;
  bool ok = engine.Reset(timeout_ms, error);

  PutMapEntry(env, map, "ok", BooleanBox(env, ok));
  PutMapEntry(env, map, "error", env->NewStringUTF(error.c_str()));
  return map;
}

JNIEXPORT jobject JNICALL
Java_com_qfildroid_app_protocol_ProtocolBridge_firehoseCommand(
    JNIEnv* env, jobject /*thiz*/, jstring device_key, jstring xml,
    jint timeout_ms) {
  jobject map = NewResultMap(env);
  const char* key = env->GetStringUTFChars(device_key, nullptr);
  JniUsbTransport transport(env, key);
  env->ReleaseStringUTFChars(device_key, key);

  if (!transport.Valid()) {
    PutMapEntry(env, map, "ok", BooleanBox(env, false));
    PutMapEntry(env, map, "error", "native USB bridge unavailable");
    return map;
  }

  const char* xml_chars = env->GetStringUTFChars(xml, nullptr);
  std::string command(xml_chars);
  env->ReleaseStringUTFChars(xml, xml_chars);

  qfildroid::firehose::FirehoseEngine engine(transport);
  qfildroid::firehose::Response response;
  engine.SendCommand(command, timeout_ms, response);

  PutMapEntry(env, map, "ok", BooleanBox(env, response.ack));
  PutMapEntry(env, map, "parsed", BooleanBox(env, response.parsed));
  PutMapEntry(env, map, "response", env->NewStringUTF(response.raw.c_str()));
  PutMapEntry(env, map, "error", env->NewStringUTF(response.error.c_str()));

  jclass list_class = env->FindClass("java/util/ArrayList");
  jmethodID list_ctor = env->GetMethodID(list_class, "<init>", "()V");
  jobject logs = env->NewObject(list_class, list_ctor);
  jmethodID add = env->GetMethodID(list_class, "add", "(Ljava/lang/Object;)Z");
  for (const std::string& log : response.logs) {
    env->CallBooleanMethod(logs, add, env->NewStringUTF(log.c_str()));
  }
  env->DeleteLocalRef(list_class);
  PutMapEntry(env, map, "logs", logs);
  return map;
}

}  // extern "C"
