
#include <binder/BinderService.h>
#include <binder/IPCThreadState.h>
#include <binder/ProcessState.h>
#include <binder/IServiceManager.h>
#include <binder/IPermissionController.h>


namespace android {

class FakePermissionService :
	public BinderService<FakePermissionService>,
	public BnPermissionController
{
public:
	FakePermissionService();
	virtual ~FakePermissionService();
	static const char *getServiceName() { return "permission"; }

	virtual status_t dump(int fd, const Vector<String16>& args);
	virtual bool checkPermission(const String16& permission, int32_t pid, int32_t uid);
};

FakePermissionService::FakePermissionService()
  : BnPermissionController()
{
}

FakePermissionService::~FakePermissionService()
{
}

status_t
FakePermissionService::dump(int fd, const Vector<String16>& args)
{
	return NO_ERROR;
}

bool
FakePermissionService::checkPermission(const String16& permission, int32_t pid, int32_t uid)
{
	return true;
}
}; // namespace android

using namespace android;

int main(int argc, char **argv)
{
	FakePermissionService::publishAndJoinThreadPool();
	return 0;
}
