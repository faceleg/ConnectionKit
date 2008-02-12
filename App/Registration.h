
// Licensing
enum { kSingleLicense, kHouseholdLicense, kSiteLicense, kWorldwideLicense };
enum { kComp, kKagi, kPaypal, kStore };
enum { kAnonymous, kNamed };

#define kKTMaxLicensesPerHousehold 4
// should match $$HOUSEHOLD_MAX_USERS in PHP

// REGISTRATION
//  obfuscation
#ifndef DEBUG

#define gRegistrationFailureCode kKTPageletUniqueID
#define gRegistrationString kKTUploadProperties
#define gLicenseIsBlacklisted kKTUploadEnabled
#define gLicenseViolation kKTDragEnabled
#define gRegistrationWasChecked kKTDragEnabledForPagelet
#define gRegistrationHash kKTDragCode
#define gLicensee kKTEventModifier
#define gLicenseType kKTFontSizeAdjustment
#define gIsPro kKTFontStyle
#define gSeats kKTFontWeight
#define gLicenseVersion kDocumentWidthMinimum
#define gLicenseDate kDocumentPublicationTimestamp

#endif

// vars defined in KTApplication.m
extern NSString *gRegistrationString;
extern int gLicenseIsBlacklisted;
extern int gLicenseViolation;
extern int gRegistrationWasChecked;
extern int gRegistrationFailureCode;
extern NSString *gRegistrationHash;
extern NSString *gLicensee;
extern NSDate *gLicenseDate;
extern int gLicenseType;
extern int gIsPro;
extern unsigned int gSeats;
extern int gLicenseVersion;

// REGISTRATION
//  obfuscation
#ifndef DEBUG

#define checkRegistrationString hideNewsWindow
#define registrationReport expandToFillWindow
#define codeIsValid webviewUpdate
#define calculateStringChecksum resizeViews
#define hashDataFromLicenseString cleanHTML
#define registrationHash brokenDownIntoComponents
#define isPro frontmostApplication

#endif

enum { kKTLicenseOK, kKTCouldNotReadLicenseFile, kKTBlacklisted, kKTLicenseExpired, kKTNoLongerValid, kKTLicenseCheckFailed };

// strings
extern NSString *gFunnyFileName;
