//
//  KTAbstractBugReporter.h
//  Marvel
//
//  Created by Terrence Talbot on 12/23/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// do not localize, it's used only for our reports
#define ANONYMOUS_ADDRESS @"Anonymous"


@interface KTAbstractBugReporter : NSObject 
{
    IBOutlet NSWindow               *oReportWindow;
    
	IBOutlet NSView					*oGenericProgressView;
	IBOutlet NSProgressIndicator	*oGenericProgressIndicator;
	IBOutlet NSTextField			*oGenericProgressTextField;
	IBOutlet NSTextField			*oGenericProgressRedTextField;
	
	IBOutlet NSView					*oAccessoryView;
	IBOutlet NSButton				*oOpenSavedFeedbackSwitch;
    
	NSPanel *myGenericProgressPanel;
}

#pragma mark IBActions

// subclasses must override to bring oReportWindow onscreen 
- (IBAction)showReportWindow:(id)sender;

// default button action (initiates packaging up and submitting reportDictionary)
- (IBAction)submitReport:(id)sender;

// optional, other button action (closes window without submitting)
- (IBAction)cancelReport:(id)sender;

// not yet implemented, would be connected to ? help button
- (IBAction)displayHelp:(id)sender;

- (IBAction) windowHelp:(id)sender;

#pragma mark subclass responsibilities

// may be implemented by subclasses to provide a re-usable singleton of the subclass
+ (id)sharedInstance;

// must load class specific nib containing oReportWindow
- (void)loadAndPrepareReportWindow;

// must orderOut: oReportWindow and, optionally, clear/reset controls
- (void)clearAndCloseWindow;

// must return localized filename to show in .rtfd Save panel, e.g., "Feedback Report"
- (NSString *)defaultReportFileName;

// must return key/value pairs to be encoded and submitted to submitURL
- (NSDictionary *)reportDictionary;

// must return a human-readable version of reportDictionary to be saved as .rtfd
- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary;

// must return the URL of the form that the reportDictionary will be submitted to
- (NSURL *)submitURL;

#pragma mark support

// derived
- (NSString *)appName;
- (NSString *)appVersion;
- (NSString *)appBuildNumber;
- (NSString *)systemVersion;

// returns console log as string
- (NSString *)consoleLog;
- (NSString *)consoleLogFilteredForName:(NSString*)aProcessName;

// returns defaults for aBundleIndentifier, e.g., com.karelia.Sandvox
- (NSData *)preferencesAsSerializedPropertyListForBundleIdentifier:(NSString *)aBundleIdentifier;

// replaces all occurrences of \n with \r\n
- (NSString *)fixUpLineEndingsForScoutSubmit:(NSString *)aString;

// returns key/value pairs in aDictionary as encoded multpart form
- (NSMutableData *)formDataWithDictionary:(NSDictionary *)aDictionary;

@end

// this associated class allows packaging of NSData with filename to be submitted as email attachment
@interface KTFeedbackAttachment : NSObject
{
	NSString *myFileName;
	NSData *myData;
}
+ (KTFeedbackAttachment *)attachmentWithFileName:(NSString *)aFileName data:(NSData *)theData;
+ (KTFeedbackAttachment *)attachmentWithContentsOfFile:(NSString *)aPath;
- (NSString *)fileName;
- (void)setFileName:(NSString *)aFileName;
- (NSData *)data;
- (void)setData:(NSData *)theData;
@end

/* feedbackReporterSubmit.php form fields
    customerEmail (email + name)
    classification
    summary
    caseNumber
    details
    exceptionName
    exceptionReason
    backtrace
    appName
    appVersion
    appBuildNumber
    systemVerison
    errorCode
    errorDomain
    errorDescription
    errorReason
    additionalPlugins
    additionalDesigns
    license
    ccMyself

    console
    screenshot1
    screenshot2
    screenshot3
    otherAttachment
*/

/* scoutSubmit.php form fields
    ScoutUserName       (Valid FogBugz User Name)
    ScoutProject        (Existing Project Name)
    ScoutArea           (Existing Area Name)
    Description         (becomes Case name, should follow common pattern)
    Extra               (user's description of bug)
    Email               (Customer's Email Address)
    ForceNewBug         (1 to force new entry, 0 to append to bug with matching Description)
    ScoutDefaultMessage (string to return on successful submission, should be "OK")
    FriendlyResponse    (1 responds as HTML, 0 as XML, should be 1)
*/
