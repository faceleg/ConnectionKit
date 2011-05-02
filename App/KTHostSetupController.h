//
//  KTHostSetupController.h
//  Marvel
//
//  Created by Dan Wood on 11/10/04.
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>
#import "KSSingletonWindowController.h"

@class KTHostProperties;

enum { DOT_MAC = 0, UNUSED_NOW, OTHER_ISP };
enum { WEBDAV = 0, FTP, DOTMAC };
enum { HOMEDIR = 0, SHARED };

enum { PERSONAL_DOTMAC_DOMAIN, HOMEPAGE_MAC_COM, WEB_MAC_COM, WEB_ME_COM };
enum { TEST_UPLOAD = 1, TEST_FETCH, TEST_DELETE };	// states for testing connection

enum { LOCALHOST_UNVERIFIED = -1, LOCALHOST_REACHABLE = 0, LOCALHOST_UNREACHABLE, LOCALHOST_WRONGCOMPUTER, LOCALHOST_404, LOCALHOST_NOAPACHE };
// > 0 MEANS AN ERROR OF SOME SORT

/*
 tags of tabviews:
	introduction
	where
	apache
	local
	localError
	mac
NO LONGER	choose
	host
	account
	test
NO LONGER	save
	summary

 keys
	localHosting (boolean)
	remoteHosting (boolean)

	localHostName
	localSubFolder

	provider
	regions
	notes
	storageLimitMB

	homePageURL
	setupURL

	hostName
	port
	docRoot
	stemURL
	transferMatrix 0 (WebDav), 1 (FTP)
		--> protocol ftp, webdav, ssh

	subFolder
	userName
	password -- NOT stored in dictionary, TODO store in keychain

	passedUploadURL

	// not really used other than to control flow
	hostTypeMatrix -- 0 (ISP), 1 (.mac), 2 (other)
	localSharedMatrix == 0 (Home dir), 1 (computer)

	isEditing provides for different paths through the HSA if the values are being edited a second time through
*/
@class KTBackgroundTabView;

@interface KTHostSetupController : KSSingletonWindowController
{
	BOOL myShouldShowConnectionTroubleshooting;
	BOOL myWantsNextWhenDoneLoading;
	BOOL myDidSuccessfullyDownloadTestFile;
	BOOL myHasProcessedDidChangeToDirectory;
	
	int	myLocalHostVerifiedStatus;
	int myTestState;
	int myWasApacheRunning;
	
	IBOutlet KTBackgroundTabView *oTabView;
	IBOutlet NSButton *oGetDotMacButton;
	IBOutlet NSButton *oNextButton;
	IBOutlet NSButton *oPreviousButton;
	IBOutlet NSButton *oDotMacSetupLink;
	IBOutlet NSMatrix *oHostTypeMatrix;
	IBOutlet NSObjectController *oMainObjectController;
	IBOutlet NSPanel *oBrowseHostAccountPanel;
	IBOutlet NSTextField *oApacheLabel;
	IBOutlet NSTextField *oBrowseHostPassword;
	IBOutlet NSTextField *oBrowseHostUsername;
	IBOutlet NSTextField *oDotMacLabel;
	IBOutlet NSTextField *oLocalHostErrorString;
	IBOutlet NSTextField *oPasswordField;
	IBOutlet NSTextField *oPortField;
	IBOutlet NSTextField *oStepLabel;
	IBOutlet NSTextView *oIntroductionTextView;
	IBOutlet NSTextView *oSummaryTextView;
	IBOutlet NSTextField *oRecommendation;

	CKAbstractConnection *myTestConnection;
	NSColor *myConnectionStatusColor;
	NSMutableArray *myTrail;
	NSMutableData *myConnectionData;
	NSMutableData *myISPConnectionData;
	NSMutableDictionary *myOriginalProperties;
	KTHostProperties	*myProperties;
	NSString *myConnectionProgress;
	NSString *myConnectionStatus;
	NSString *myCurrentState;
	NSString *myDefaultISP;
	NSString *myPassword;
	NSString *myRemotePath;
	NSString *myTemporaryTestFilePath;
	NSString *myTestStatusString;
	NSTimer *myApacheTimer;
	NSTimer *myDotMacTimer;
	NSURLConnection *myDownloadTestConnection;
	NSURLConnection *myReachableConnection;
}

- (IBAction) windowHelp:(id)sender;
- (IBAction) doNext:(id)sender;
- (IBAction) doPrevious:(id)sender;
- (IBAction) doCancel:(id)sender;
- (IBAction) doOK:(id)sender;
- (IBAction) doDotMacConfigure:(id)sender;
- (IBAction) doSharingConfigure:(id)sender;
- (IBAction) doVerifyHomePageURL:(id)sender;
- (IBAction) doVerifySetupURL:(id)sender;
- (IBAction) doGetDotMacAccount:(id)sender;
- (IBAction) createNewConfiguration:(id)sender;
- (IBAction) browseHostToSelectPath:(id)sender;
- (IBAction) openPreferredHost:(id)sender;
- (IBAction) settingUpDotMacPersnalDomains:(id)sender;


- (NSMutableData *)connectionData;
- (void)setConnectionData:(NSMutableData *)aConnectionData;
- (NSURLConnection *)reachableConnection;
- (void)setReachableConnection:(NSURLConnection *)aReachableConnection;
- (NSURLConnection *)downloadTestConnection;
- (void)setDownloadTestConnection:(NSURLConnection *)aDownloadTestConnection;

- (CKAbstractConnection *)testConnection;
- (void)setTestConnection:(CKAbstractConnection *)aTestConnection;

- (int)testState;
- (void)setTestState:(int)aTestState;

- (int)localHostVerifiedStatus;
- (void)setLocalHostVerifiedStatus:(int)aLocalHostVerifiedStatus;

- (id)initWithHostProperties:(KTHostProperties *)hostProperties;

- (NSString *)temporaryTestFilePath;
- (void)setTemporaryTestFilePath:(NSString *)aTemporaryTestFilePath;

- (BOOL)wantsNextWhenDoneLoading;
- (void)setWantsNextWhenDoneLoading:(BOOL)flag;

- (NSString *)defaultISP;
- (void)setDefaultISP:(NSString *)aDefaultISP;

- (KTHostProperties *)properties;
- (void)setProperties:(KTHostProperties *)aProperties;

- (NSMutableDictionary *)originalProperties;
- (void)setOriginalProperties:(NSMutableDictionary *)anOriginalProperties;

- (NSMutableArray *)trail;
- (void)setTrail:(NSMutableArray *)aTrail;

- (NSString *)currentState;
- (void)setCurrentState:(NSString *)aCurrentState;

- (NSString *)connectionProgress;
- (void)setConnectionProgress:(NSString *)aConnectionProgress;

- (NSString *)connectionStatus;
- (void)setConnectionStatus:(NSString *)aConnectionStatus;

- (NSTimer *)dotMacTimer;
- (void)setDotMacTimer:(NSTimer *)aDotMacTimer;

- (NSTimer *)apacheTimer;
- (void)setApacheTimer:(NSTimer *)anApacheTimer;

- (NSString *)password;
- (void)setPassword:(NSString *)aPassword;

- (NSColor *)connectionStatusColor;
- (void)setConnectionStatusColor:(NSColor *)aConnectionStatusColor;

- (NSString *)localURL;
- (NSString *)globalSiteURL;
- (NSString *)remoteSiteURL;
- (NSString *)uploadURL;
- (BOOL)remoteSiteURLIsValid;


@end

