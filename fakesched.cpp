/*
 * Copyright (C) 2012-2013 Mozilla Foundation
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
#include <binder/IServiceManager.h>
#include <ISchedulingPolicyService.h>

namespace android {

class FakeSchedulePolicyService :
    public BinderService<FakeSchedulePolicyService>,
    public BnSchedulingPolicyService
{
public:
    FakeSchedulePolicyService();
    virtual ~FakeSchedulePolicyService();
    static const char *getServiceName() { return "scheduling_policy"; }

    virtual status_t dump(int fd, const Vector<String16>& args);
    virtual int requestPriority(int32_t pid, int32_t tid, int32_t prio, bool async);
};

FakeSchedulePolicyService::FakeSchedulePolicyService()
  : BnSchedulingPolicyService()
{
}

FakeSchedulePolicyService::~FakeSchedulePolicyService()
{
}

status_t
FakeSchedulePolicyService::dump(int fd, const Vector<String16>& args)
{
    return NO_ERROR;
}

int
FakeSchedulePolicyService::requestPriority(int32_t pid, int32_t tid, int32_t prio, bool async)
{
    return 0; /* PackageManger.PERMISSION_GRANTED */
}
}; // namespace android

using namespace android;

int main(int argc, char **argv)
{
    FakeSchedulePolicyService::publishAndJoinThreadPool();
    return 0;
}
