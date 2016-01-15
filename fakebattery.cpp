/*
 * Copyright (C) 2013 Mozilla Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <binder/BinderService.h>
#include <binder/IPCThreadState.h>
#include <binder/ProcessState.h>
#include <binder/IInterface.h>

#include <android/log.h>
#define ALOGE(args...)  __android_log_print(ANDROID_LOG_ERROR, "gonkbatteryinfo" , ## args)

namespace android {

class IBatteryStatsService : public IInterface
{
public:
    DECLARE_META_INTERFACE(BatteryStatsService);

    // Nothing implemented
};

class BnBatteryStatsService : public BnInterface<IBatteryStatsService>
{
public:
    virtual status_t onTransact( uint32_t code,
                                 const Parcel& data,
                                 Parcel* reply,
                                 uint32_t flags = 0);
};

// ----------------------------------------------------------------------

class BpBatteryStatsService : public BpInterface<IBatteryStatsService>
{
public:
    BpBatteryStatsService(const sp<IBinder>& impl)
        : BpInterface<IBatteryStatsService>(impl)
    {
    }
};

IMPLEMENT_META_INTERFACE(BatteryStatsService, "com.android.internal.app.IBatteryStats");

// ----------------------------------------------------------------------

status_t BnBatteryStatsService::onTransact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    return BBinder::onTransact(code, data, reply, flags);
}

// ----------------------------------------------------------------------

class FakeBatteryStatsService :
    public BinderService<FakeBatteryStatsService>,
    public BnBatteryStatsService
{
public:
    FakeBatteryStatsService();
    virtual ~FakeBatteryStatsService();

    static const char *getServiceName() {
        return "batterystats";
    }

    virtual status_t dump(int fd, const Vector<String16>& args) {
        return NO_ERROR;
    }
};

FakeBatteryStatsService::FakeBatteryStatsService()
    : BnBatteryStatsService()
{
}

FakeBatteryStatsService::~FakeBatteryStatsService()
{
}

}; // namespace android

using namespace android;

int main(int argc, char **argv)
{
    FakeBatteryStatsService::publishAndJoinThreadPool();
    return 0;
}
