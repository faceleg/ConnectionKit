//
//  KTAbstractBugReporter.m
//  Marvel
//
//  Created by Terrence Talbot on 12/23/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTAbstractBugReporter.h"

#import "KTApplication.h"
#import <Sandvox.h>
#import <asl.h>


#define HTTP_POST_STRING_BOUNDARY	@"0xKhTmLbOuNdArY"
#define HTTP_REPLY_OK               @"OK"


static NSString *sUnableToContactServerAlert = @"UnableToContactServer";
static NSString *sSaveFeedbackPanel = @"SaveFeedback";
static NSString *sOpenFeedbackInWorkspaceDefaultsKey = @"OpenReportInWorkspace"; // must match binding in oAccessoryView


@interface KTAbstractBugReporter ( Private )
- (BOOL)saveRTFDToPath:(NSString *)aPath;
@end


@implementation KTAbstractBugReporter

#pragma mark init

- (id)init
{
    if ( nil == [super init] )
    {
        return nil;
    }
    
    // make sure we have supplementary UI loaded
    if ( nil == oGenericProgressTextField )
    {
        (void)[NSBundle loadNibNamed:@"BugReporterViews" owner:self];
		
		// set up a reusable, generic progress panel
		myGenericProgressPanel = [[NSPanel alloc] initWithContentRect:[oGenericProgressView bounds]
															styleMask:NSTitledWindowMask
															  backing:NSBackingStoreBuffered
																defer:YES];
		[myGenericProgressPanel setTitle:[NSApplication applicationName]];
		[myGenericProgressPanel setContentView:oGenericProgressView];
		[myGenericProgressPanel setLevel:NSModalPanelWindowLevel];
		[oGenericProgressRedTextField setHidden:YES];
    }
    if ( nil != oGenericProgressRedTextField )
	{
		[oGenericProgressRedTextField setHidden:YES];
		[oGenericProgressRedTextField setTextColor:[[NSColor greenColor] shadowWithLevel:0.25]]; /// red looks like an error, let's make it (darkish) green
	}
	
	// load subclass UI
	[self loadAndPrepareReportWindow];
    
//#ifdef DEBUG
//    oReportWindow = nil;
//	oGenericProgressView = nil;
//	oGenericProgressIndicator = nil;
//	oGenericProgressTextField = nil;
//	oAccessoryView = nil;
//	oOpenSavedFeedbackSwitch = nil;
//	
//#endif
	
	
	
    return self;
}

#pragma mark dealloc

- (void)dealloc
{
	[myGenericProgressPanel release];
	[super dealloc];
}

#pragma mark IBActions

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"Support_and_Feedback"];
}

- (IBAction)showReportWindow:(id)sender
{
	[self subclassResponsibility:_cmd];
}

- (IBAction)displayHelp:(id)sender
{
	; // not (yet) implemented
}

- (IBAction)cancelReport:(id)sender
{
    [self clearAndCloseWindow];
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Support_and_Feedback";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (IBAction)submitReport:(id)sender
{
	[oGenericProgressRedTextField setHidden:YES];
	// put up progress sheet
	[oGenericProgressTextField setStringValue:NSLocalizedString(@"Sending report to Karelia...", 
																"Message to user during HTTP submit")];
	[oGenericProgressIndicator setUsesThreadedAnimation:YES];
    [oGenericProgressIndicator startAnimation:nil];
	[NSApp beginSheet:myGenericProgressPanel
	   modalForWindow:oReportWindow 
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
 	[NSApp cancelUserAttentionRequest:NSCriticalRequest];
   
	// create the request
	NSURL *submitURL = [self submitURL];
	NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:submitURL];
	
	// add header information
	[postRequest setHTTPMethod:@"POST"];
	
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", HTTP_POST_STRING_BOUNDARY];
	[postRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
	
	NSDictionary *submitDict = [self reportDictionary];
	
	// convert submitDict to a POST
	NSMutableData *postBody = [self formDataWithDictionary:submitDict];
	[postRequest setHTTPBody:postBody];
	
	// POST it! (this blocks until server responds)
	NSURLResponse *response = nil;
	NSError *error = nil;
	NSData *result = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
    
	// stop the progress animation
	[oGenericProgressIndicator stopAnimation:nil];
	[oGenericProgressIndicator setUsesThreadedAnimation:NO];
    
	NSTimeInterval delay = 2.0;
	
    if ( (nil != result) && ([result length] > 0) )
    {
        // something was returned by the server...
        // display the returned message
        NSString *reply = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        if ( [reply isEqualToString:HTTP_REPLY_OK] )
        {
            [oGenericProgressTextField setStringValue:NSLocalizedString(@"Thanks for submitting your report.", 
                                                                        "Message to user following successful HTTP submit")];
			NSString *email = [submitDict objectForKey:@"customerEmail"];
			BOOL anonymous = [email isEqualToString:ANONYMOUS_ADDRESS];
			[oGenericProgressRedTextField setHidden:anonymous];
			if (!anonymous)
			{
				delay = 5.0;
			}
            NSLog(@"Reporter: Karelia has received the feedback.");
        }
        else
        {
			[oGenericProgressRedTextField setHidden:YES];
            [oGenericProgressTextField setStringValue:reply];
            NSLog(@"Reporter: %@", reply);
        }
        
        [oGenericProgressTextField display];
        [oGenericProgressRedTextField display];
        [reply release];
        
        // wait two seconds before closing sheet
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:delay]];
        
        // take down progress sheet
        [NSApp endSheet:myGenericProgressPanel];
        [myGenericProgressPanel orderOut:nil];
        
        // wait one second before closing window
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        
        // close window
        [self clearAndCloseWindow];
        return;
    }
    else
    {
        // something went wrong, a connection to the server could not be created...
        // inform user and give them an opportunity to save and submit on their own
        NSLog(@"Reporter: unable to contact Karelia support at %@ .... %@", [self submitURL], result);
        if ( nil != error )
        {
            NSLog(@"Reporter: error: %@ -- %@ %d", [error localizedDescription], [error domain], [error code]);
        }
        
        // take down progress sheet
        [NSApp endSheet:myGenericProgressPanel];
        [myGenericProgressPanel orderOut:nil];        
        
        // allow user the opportunity to save and submit on their own
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to contact Karelia support.", 
                                                                         "Message to user following network error") 
                                         defaultButton:NSLocalizedString(@"Save Report...",
                                                                         "Save Report... Button")
                                       alternateButton:NSLocalizedString(@"Don\\U2019t Save", 
                                                                         "Don't Save Button") 
                                           otherButton:NSLocalizedString(@"Cancel",
                                                                         "Cancel Button") 
                             informativeTextWithFormat:NSLocalizedString(@"There was a problem contacting Karelia's servers. Your report could not be submitted. Please consider saving to a file and emailing that file directly to Karelia.",
                                                                         "Message to user that feedback server could not be contacted")];

		[alert setShowsHelp:YES];
		[alert setDelegate:self];

		[alert beginSheetModalForWindow:oReportWindow 
                          modalDelegate:self 
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
                            contextInfo:sUnableToContactServerAlert];
    }
}

#pragma mark alerts/panels

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{    
	NSWindow *sheet = [alert window];
	[sheet orderOut:nil];
	
    switch ( returnCode )
    {
        case NSAlertDefaultReturn: // OK, save to rtfd
        {
            NSSavePanel *savePanel = [NSSavePanel savePanel];
			[savePanel setRequiredFileType:@"rtfd"];
			[savePanel setAccessoryView:oAccessoryView];
			
			NSString *desktopDirectory = [[NSWorkspace sharedWorkspace] folderWithType:kDesktopFolderType];
			
            [savePanel beginSheetForDirectory:desktopDirectory
                                         file:[self defaultReportFileName]
                               modalForWindow:oReportWindow 
                                modalDelegate:self 
                               didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
                                  contextInfo:sSaveFeedbackPanel];
            break;
        }
        case NSAlertAlternateReturn: // Don't Save, close the window
        {
            [self clearAndCloseWindow];
            break;
        }
        case NSAlertOtherReturn: // Cancel, don't do anything, leave the window up
        default:
        {
            break;
        }
    }
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    NSString *path = [sheet filename];
    [sheet orderOut:nil];
    
    switch ( returnCode )
    {
        case NSOKButton:
        {
            if ( [self saveRTFDToPath:path] )
            {
                [self clearAndCloseWindow];
				BOOL openFeedback = [[NSUserDefaults standardUserDefaults] boolForKey:sOpenFeedbackInWorkspaceDefaultsKey];
				if ( openFeedback )
				{
					[[NSWorkspace sharedWorkspace] openFile:path];
				}
            }
            break;
        }
        case NSCancelButton:
        default:
        {
            break;
        }
    }
}

- (BOOL)saveRTFDToPath:(NSString *)aPath
{
	BOOL result = NO;
	
	// construct rtfd report
	NSAttributedString *rtfdString = [self rtfdWithReport:[self reportDictionary]];
	
	// write as rtfd file
	NSFileWrapper *rtfdWrapper = [rtfdString RTFDFileWrapperFromRange:NSMakeRange(0,[rtfdString length])
												   documentAttributes:nil];
	result = [rtfdWrapper writeToFile:aPath atomically:YES updateFilenames:YES];
	
	// hide the file extension (doesn't seem to work)
	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSFileExtensionHidden];
	(void)[[NSFileManager defaultManager] changeFileAttributes:attrs
														atPath:aPath];
	
    return result;
}

#pragma mark subclass responsibilities

+ (id)sharedInstance
{
	[self subclassResponsibility:_cmd];
    return nil;
}

- (void)loadAndPrepareReportWindow
{
	[self subclassResponsibility:_cmd];
}

- (void)clearAndCloseWindow
{
	[self subclassResponsibility:_cmd];
}

- (NSString *)defaultReportFileName
{
	[self subclassResponsibility:_cmd];
    return nil;
}

- (NSDictionary *)reportDictionary
{
	[self subclassResponsibility:_cmd];
    return nil;
}

- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary
{
	[self subclassResponsibility:_cmd];
    return nil;
}

- (NSURL *)submitURL
{
	[self subclassResponsibility:_cmd];
    return nil;
}

#pragma mark console

- (NSString *)consoleLog
{
    return [self consoleLogFilteredForName:nil];
}

- (NSString *)consoleLogFilteredForName:(NSString*)aProcessName
{
	NSString *consoleLog = nil;

	//if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
	if (floor(NSAppKitVersionNumber) <= 824)
	{
		/* On a 10.4 - 10.4.x system */
		NSString *path;
		NSFileManager *mgr = [NSFileManager defaultManager];
		
//	TODO:	With a huge console log file, this is very memory inefficient.  Probably better to grep from the file as an NSTask.  Or Terrence wants us to use a separate file so it would no longer be needed to grep.
		
		// get console from Logs directory
		path = [NSString stringWithFormat:@"/Library/Logs/Console/%d/console.log", getuid()]; //10.4
		path = [path stringByResolvingSymlinksInPath];
		if([mgr fileExistsAtPath:path])
		{
			consoleLog = [NSString stringWithContentsOfFile:path];
		}
		
		// filter the log to display just lines containing aProcessName
		if ( nil != aProcessName )
		{
			NSMutableString *filteredLog = [NSMutableString stringWithCapacity:1000];
			NSArray *lines = [consoleLog componentsSeparatedByString:@"\n"];
			NSEnumerator *e = [lines objectEnumerator];
			NSString *line = nil;
			while ( line = [e nextObject] )
			{
				NSRange range = [line rangeOfString:aProcessName];
				if ( NSNotFound != range.location )
				{
					[filteredLog appendFormat:@"%@\n", line];
				}
			}
			
			[filteredLog replaceOccurrencesOfString:@"\r\n"
										 withString:@"\n"
											options:NSCaseInsensitiveSearch
											  range:NSMakeRange(0, [filteredLog length])];
			
			consoleLog = [NSString stringWithString:filteredLog];
		}		
	}
	else
	{
		/* Leopard or later system */
		NSMutableString *leopardLog = [NSMutableString stringWithCapacity:(80*500)];
		
		NSString *logCTime = nil;
		NSString *logTime = nil;
		NSString *logMessage = nil;
		NSString *logLevel = nil;
		NSString *logPID = nil;
		NSString *logSender = nil;

		time_t secondsSince1970;
		int level;
		
		aslmsg q, m;
		const char *asl_time, *asl_message, *asl_level, *asl_pid, *asl_sender;
		
		q = asl_new(ASL_TYPE_QUERY);
		asl_set_query(q, ASL_KEY_SENDER, [aProcessName UTF8String], ASL_QUERY_OP_EQUAL);
		
		aslresponse r = asl_search(NULL, q);
		while ( NULL != (m = aslresponse_next(r)) )
		{ 
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			asl_time = asl_get(m, ASL_KEY_TIME);
			asl_message = asl_get(m, ASL_KEY_MSG);
			asl_level = asl_get(m, ASL_KEY_LEVEL);
			asl_pid = asl_get(m, ASL_KEY_PID);
			asl_sender = asl_get(m, ASL_KEY_SENDER);
			
			if ( NULL != asl_time )
			{
				secondsSince1970 = atol(asl_time);
				logCTime = [NSString stringWithUTF8String:ctime(&secondsSince1970)];
				logTime = [logCTime substringToIndex:24];
			}
			else
			{
				logTime = @"Empty Time";
			}
			
			if ( NULL != logMessage )
			{
				logMessage = [NSString stringWithUTF8String:asl_message];
			}
			else
			{
				logMessage = @"Empty Message";
			}
			
			if ( NULL != asl_level )
			{
				level = atoi(asl_level);
				switch ( level )
				{
					case ASL_LEVEL_EMERG:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_EMERG];
						break;
					case ASL_LEVEL_ALERT:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_ALERT];
						break;
					case ASL_LEVEL_CRIT:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_CRIT];
						break;
					case ASL_LEVEL_ERR:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_ERR];
						break;
					case ASL_LEVEL_WARNING:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_WARNING];
						break;
					case ASL_LEVEL_NOTICE:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_NOTICE];
						break;
					case ASL_LEVEL_INFO:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_INFO];
						break;
					case ASL_LEVEL_DEBUG:
						logLevel = [NSString stringWithUTF8String:ASL_STRING_DEBUG];
						break;
					default:
						logLevel = @"Unknown Level"; // let's not ever return nil
				}
			}
			else
			{
				logLevel = @"Empty Level";
			}
			
			if ( NULL != asl_pid )
			{
				logPID = [NSString stringWithUTF8String:asl_pid];
			}
			else
			{
				logPID = @"Empty PID";
			}
			
			if ( NULL != asl_sender )
			{
				logSender = [NSString stringWithUTF8String:asl_sender];
			}
			else
			{
				logSender = @"Empty Sender";
			}
			
			[leopardLog appendFormat:@"%@ %@[%@] <%@>: %@\n", logTime, logSender, logPID, logLevel, logMessage];
			
			[pool release];
		}
		aslresponse_free(r);
		consoleLog = [NSString stringWithString:leopardLog];
	}
		
	if ( (nil == consoleLog) || !([consoleLog length] > 0) )
	{
		consoleLog = @"Empty Log";
		if ( nil != aProcessName )
		{
			consoleLog = [consoleLog stringByAppendingFormat:@" (filtered for %@)", aProcessName];
		}
	}
	
	return consoleLog;
}

#pragma mark preferences

- (NSData *)preferencesAsSerializedPropertyListForBundleIdentifier:(NSString *)aBundleIdentifier
{
	CFArrayRef appKeys = CFPreferencesCopyKeyList(
												  (CFStringRef)aBundleIdentifier,
												  kCFPreferencesCurrentUser,
												  kCFPreferencesAnyHost
												  );
	
	CFDictionaryRef prefs = CFPreferencesCopyMultiple(
													  appKeys,
													  (CFStringRef)aBundleIdentifier,
													  kCFPreferencesCurrentUser,
													  kCFPreferencesAnyHost
													  );
	
	return [NSPropertyListSerialization dataFromPropertyList:(NSDictionary *)prefs
													  format:NSPropertyListXMLFormat_v1_0
											errorDescription:nil];
	CFRelease(appKeys);
	CFRelease(prefs);
}

#pragma mark support

- (NSString *)appName
{
    return [[NSProcessInfo processInfo] processName];
}

- (NSString *)appVersion
{
    return [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
}

- (NSString *)appBuildNumber
{
    return [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
}

- (NSString *)systemVersion
{
	return [NSString stringWithFormat:@"%@ - %@", 
		[[NSProcessInfo processInfo] operatingSystemVersionString],
		[KTApplication machineName]];
}

// replaces all occurrences of \n with \r\n
- (NSString *)fixUpLineEndingsForScoutSubmit:(NSString *)aString
{
	NSMutableString *mutableString = [aString mutableCopy];
	
	// Convert any CRLF's to newlines so we're all starting on the same page
	[mutableString replaceOccurrencesOfString:@"\r\n"
								   withString:@"\n"
									  options:NSCaseInsensitiveSearch
										range:NSMakeRange(0, [mutableString length])];
	
	// Now make all newlines be CRLF
	[mutableString replaceOccurrencesOfString:@"\n"
								   withString:@"\r\n"
									  options:NSCaseInsensitiveSearch
										range:NSMakeRange(0, [mutableString length])];
	NSString *result = [NSString stringWithString:mutableString];
	[mutableString release];
	
	return result;
}

// returns key/value pairs in aDictionary as encoded multpart form
- (NSMutableData *)formDataWithDictionary:(NSDictionary *)aDictionary
{
	NSMutableData *result = [[NSMutableData alloc] initWithCapacity:100];
	
	NSEnumerator *e = [[aDictionary allKeys] objectEnumerator];
	NSString *key = nil;
	while ( key = [e nextObject] )
	{
		[result appendData:[[NSString stringWithFormat:@"--%@\r\n", HTTP_POST_STRING_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];
		
		id value = [aDictionary valueForKey:key];
		if ( [value isKindOfClass:[NSString class]] )
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
			[result appendData:[[NSString stringWithFormat:@"%@",value] dataUsingEncoding:NSUTF8StringEncoding]];
		}
		else if ( [value isKindOfClass:[NSURL class]] && [value isFileURL] )
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, [[value path] lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding]];
			[result appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			[result appendData:[NSData dataWithContentsOfFile:[value path]]];			
		}
		else if ( [value isKindOfClass:[KTFeedbackAttachment class]] )
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, [value fileName]] dataUsingEncoding:NSUTF8StringEncoding]];
			[result appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			[result appendData:[value data]];			
		}
		
		[result appendData:[[NSString stringWithString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	[result appendData:[[NSString stringWithFormat:@"--%@--\r\n", HTTP_POST_STRING_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];
	
    return [result autorelease];
}

@end


@implementation KTFeedbackAttachment

+ (KTFeedbackAttachment *)attachmentWithFileName:(NSString *)aFileName data:(NSData *)theData
{
	KTFeedbackAttachment *result = [[self alloc] init];
	
	[result setData:theData];
	[result setFileName:aFileName];
	
	return [result autorelease];
}

+ (KTFeedbackAttachment *)attachmentWithContentsOfFile:(NSString *)aPath
{
	NSData *data = [NSData dataWithContentsOfFile:aPath];
	NSString *fileName = [aPath lastPathComponent];
	
	return [self attachmentWithFileName:fileName data:data];
}

- (void)dealloc
{
	[myFileName release];
	[myData release];
	[super dealloc];
}

- (NSString *)fileName
{
	return myFileName;
}

- (void)setFileName:(NSString *)aFileName
{
	[aFileName retain];
	[myFileName release];
	myFileName = aFileName;
}

- (NSData *)data
{
	return myData;
}

- (void)setData:(NSData *)theData
{
	[theData retain];
	[myData release];
	myData = theData;
}

@end

