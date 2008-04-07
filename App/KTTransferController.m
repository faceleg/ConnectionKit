//
//  KTTransferController.m
//  Marvel
//
//  Created by Dan Wood on 11/23/04.
//  Copyright 2004 Karelia Software, LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Job of this is to keep remote site updated with local database.
 There is one or two of these objects per document -- one for local hosting, one for global hosting.
 It gets its settings from the connection dictionary
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
 
 IMPLEMENTATION NOTES & CAUTIONS:
	x
 
 TO DO:
 
 After we edit the settings, we compare the host, username, subfolder: new vs. old, and if it is changed, we set this as a 'virgin' posting... which means we need to publish everything we have to the new location.
 
 If we are publishing virgin, and there is already an index.html there (or other files we are trying to publish), we should alert (after collecting up all the similarities) and show a view of the curretn index.html, and show the URL so people can browse.  (or make it like an image button, click to surf in safari).  Offer choices of replace all, cancel publication
 
 Whenever there is a change to the local pages, we would notify this guy of the path of what has changed and needs to get uploaded.
 -- Added
 -- Edited
 -- Renamed
 -- Moved (one directory to another, may involve a rename too)
 
 Often changes to a single item will cascade changes to other pages.
 -- Move or Rename page means links to that page need to change
 -- Deletion may affect pages that linked to it.  (If we delete, give user option of removing
	in-line links or de-linking them, or somehow searching for them .. and cancelling
	(This implies we need an operation to look for all pages that link to this page)
 -- Adding may affect other pages if this page will go into a menu.
												   
 Who will maintain the list of dependencies? It would be nice if this did.
 This could ask a page what are the IDs of the pages it references
 but what matters is a list of what pages reference another page!  So we 
 need a list maintained by the document... for each page, what pages it 
 references, stored in a way that we can ask what references a given page.
 We ask document for its topLevelSummary, and then can traverse the contents
 [self topLevelSummary]
												   
 at each folder level, ask its fileName
 Each item, you can ask its path -- maybe useful to verify what we want and what it thinks.
 Get folder's "contents" -- array of contents
*/

#import "KTTransferController.h"
#import "KTTransferController+Internal.h"

#import "Debug.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTApplication.h"
#import "KSCircularProgressCell.h"
#import "KSUtilities.h"

#import "KTPage.h"

#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"
#import "KTDocument.h"
#import "KTHostProperties.h"
#import "KTInfoWindowController.h"
#import "KTMaster.h"
#import "KTTranscriptController.h"
#import "KTWebViewTextBlock.h"
#import "KTUtilities.h"

#import "KTMediaContainer.h"
#import "KTMediaFile.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSData+Karelia.h"
#import "NSHelpManager+KTExtensions.h"
#import "NSString+Publishing.h"
#import "NSString-Utilities.h"
#import "NSWorkspace+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSString+Karelia.h"

#import <Connection/AbstractConnection.h>
#import <Connection/FileConnection.h>
#import <Growl/Growl.h>


static NSArray *sReservedNames = nil;


@interface KTTransferController ( Private )

- (void)threadedPrepareHostForUpload;

- (void)threadedUploadDesign:(KTDesign *)design;
- (void)clearUploadedDesigns;

- (void)threadedUploadResources:(NSSet *)resources;
- (NSSet *)parsedResources;
- (void)removeAllParsedResources;

- (void)setDocumentRoot:(NSString *)docRoot;
- (void)setSubfolder:(NSString *)subfolder;

- (NSDictionary *)graphicalTextBlocks;
- (void)addGraphicalTextBlock:(KTWebViewTextBlock *)textBlock;
- (void)removeAllGraphicalTextBlocks;

- (void)pingThisURLString:(NSString *)aURLString;
@end


#pragma mark -


@implementation KTTransferController

+ (void)initialize	// +initialize is preferred over +load when possible
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	sReservedNames = [[NSArray alloc] initWithObjects:@"_Resources", @"_Media", @"placeholder", @".", nil];
	
	[self setKeys:[NSArray arrayWithObjects:@"documentRoot", @"subfolder", nil]
		triggerChangeNotificationsForDependentKey:@"storagePath"];
	
	[pool release];
}

- (id)initWithAssociatedDocument:(KTDocument *)aDocument where:(int)aWhere;
{
	if ( self = [super initWithWindowNibName:@"KTTransfer" owner:self] )
	{
		myController = [[CKTransferController alloc] init];
		[myController setIcon:[NSImage imageNamed:@"toolbar_publish"]];
		[myController setContentGeneratedInSeparateThread:YES];
		[myController setVerifyTransfers:YES];
		[myController setWaitForConnection:YES];
		[myController setDelegate:self];
		(void) [myController window];	// get window loaded
		
		myPathsCreated = [[NSMutableArray array] retain];
		myUploadedPathsMap = [[NSMutableDictionary alloc] init];
		myUploadedDesigns = [[NSMutableSet alloc] init];
		myParsedResources = [[NSMutableSet alloc] init];
		myParsedGraphicalTextBlocks = [[NSMutableDictionary alloc] init];
		myParsedMediaFileUploads = [[NSMutableSet alloc] init];
		myMediaFileUploads = [[NSMutableSet alloc] init];
		myFilesTransferred = [[NSMutableDictionary alloc] init];
		
		// get page permissions value for user defaults
		NSString *perms = [[NSUserDefaults standardUserDefaults] objectForKey:@"pagePermissions"];
		if ( nil != perms )
		{
			if ( ![perms hasPrefix:@"0"] )
			{
				perms = [NSString stringWithFormat:@"0%@", perms];
			}
			char *num = (char *)[perms UTF8String];
			unsigned int p;
			sscanf(num,"%o",&p);
			myPagePermissions = p;
		}
		
		if ( myPagePermissions == 0 )
		{
			myPagePermissions = 0644;
		}
		myDirectoryPermissions = myPagePermissions | 0111;
		
		[self setAssociatedDocument:aDocument];
		[self setWhere:aWhere];
		
		KTHostProperties *aProperties = [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties"];
		
		NSString *docRoot = nil;
		NSString *subfolder = nil;
		switch (aWhere)
		{
			case kGeneratingLocal:
			{
				if ( 1 == [[aProperties valueForKey:@"localSharedMatrix"] intValue] )
				{
					docRoot = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApacheDocRoot"];
				}
				else
				{
					docRoot = [[NSWorkspace sharedWorkspace] userSitesDirectory];
				}
				
				subfolder = [aProperties valueForKey:@"localSubFolder"];
				
				break;
			}
				
			case kGeneratingRemote:
			{
				docRoot = [aProperties valueForKey:@"docRoot"];
				subfolder = [aProperties valueForKey:@"subFolder"];
				break;
			}
				
			case kGeneratingRemoteExport:		// nothing to do here
			default:
				break;
		}
		
		[self setDocumentRoot:docRoot];
		[self setSubfolder:subfolder];
		
		[self window]; // this forces the nib to be loaded so when we do an export the accessory view is not nil.
	}
	
	return self;
}

- (void)dealloc
{
	[self setAssociatedDocument:nil];
    [self setConnection:nil];
    [myController release];		myController = nil;
    
	[myDocumentRoot release];
	[mySubfolder release];
		
	[myPublishedURL release];
    [myContentAction release];

	[myPathsCreated release];
	[myFilesTransferred release];
	[myUploadedPathsMap release];
	[myUploadedDesigns release];
	[myParsedResources release];
	[myParsedGraphicalTextBlocks release];
	[myParsedMediaFileUploads release];
	[myMediaFileUploads release];
	
	[self setDocument:nil];
	[self setConnection:nil];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	//register us as the growl delegate so we can open the page when the notification is clicked
	[GrowlApplicationBridge setGrowlDelegate:self];
}

// Since we lazily instantiate, this is really just used internally.
- (void)setConnection:(id <AbstractConnectionProtocol>)connection
{
	if (connection != myConnection)
	{
		[myConnection setDelegate:nil];
		[myConnection forceDisconnect];
		[myConnection release];
		myConnection = [connection retain];
		[myConnection setDelegate:self];
	}
}

/*!	Lazily instantiate the connection object, so we don't force a keychain access until it's needed
*/
- (id <AbstractConnectionProtocol>)connection
{
	@synchronized ( myConnection )
	{
		if (nil == myConnection)
		{
			if ([self where] == kGeneratingLocal || [self where] == kGeneratingRemoteExport)	// What about mounted file systems?
			{
				myConnection = [[FileConnection alloc] init];
			}
			else
			{
				KTHostProperties *hostProperties = [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties"];
				
				NSString *reason = @"";	// default reason -- unknown
				NSString *password = nil;
				NSString *hostName = [hostProperties valueForKey:@"hostName"];
				NSString *userName = [hostProperties valueForKey:@"userName"];
				NSString *protocol = [hostProperties valueForKey:@"protocol"];
				NSString *port = [[hostProperties valueForKey:@"port"] description];
				NSError *err = nil;
				
				if (nil != hostName
					&& nil != userName
					&& ![userName isEqualToString:@""]
					&& ![hostName isEqualToString:@""] 
					&& !([hostName hasSuffix:@"idisk.mac.com"]) 
					&& !([protocol isEqualToString:@"SFTP"] && [hostProperties boolForKey:@"usePublicKey"]))
				{
					password = [KSUtilities keychainPasswordForServer:hostName account:userName];
				}
				if (nil == password && !([hostName hasSuffix:@"idisk.mac.com"] || [protocol isEqualToString:@"SFTP"]))	// complain if it's not mac.com
				{
					reason = [NSString stringWithFormat:NSLocalizedString(
																		  @"Sandvox could not retrieve a password for %@ for server: %@",@"additional error message"), userName, hostName];
				}
				else
				{
					myConnection = [[AbstractConnection connectionWithName:protocol
																	  host:hostName
																	  port:port
																  username:userName
																  password:password
																	 error:&err] retain];
				}
				if (nil == myConnection)
				{
					[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];	// why?
					NSAlert *error;
					if (err)
					{
						error = [NSAlert alertWithError:err];
					}
					else
					{
						error = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable To Create Connection",@"couldn't make connection") 
												defaultButton:NSLocalizedString(@"OK", @"couldn't make connection")
											  alternateButton:nil
												  otherButton:nil
									informativeTextWithFormat:NSLocalizedString(@"Unable to create a connection to host '%@' with the %@ protocol. %@",@"Message in alert"), hostName, protocol, reason, nil];
					}
					
					[error beginSheetModalForWindow:[[[self associatedDocument] windowController] window]
									  modalDelegate:nil
									 didEndSelector:nil
										contextInfo:nil];
				}
				else
				{
					//LOG((@"%@ Created a connection of class %@", NSStringFromSelector(_cmd), [myConnection class]));
				}
			}
		}
	}
	return myConnection;
}

- (void)terminateConnection	// called when we are closing a window
{
	[myController stopTransfer];	// don't use [self connection] since we don't want to allocate something here
	[self setConnection:nil];
}

- (void)suspendUIUpdates
{
	if ( ![[myAssociatedDocument windowController] isSuspendingUIUpdates] )
	{
		[[myAssociatedDocument windowController] suspendUIUpdates];
	}
}

- (void)resumeUIUpdates
{
	if ( [[myAssociatedDocument windowController] isSuspendingUIUpdates] )
	{
		[[myAssociatedDocument windowController] resumeUIUpdates];
	}
}

#pragma mark -
#pragma mark Convenience wrappers

/*	Basically does the same as asking CK to upload the file, but also deletes existing files first if the Host Setup says to.
 */
- (void)uploadFile:(NSString *)localPath toFile:(NSString *)remotePath
{
	if ([[[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.deletePagesWhenPublishing"] boolValue])
	{
		[myController deleteFile:remotePath];
	}
	
	[myController uploadFile:localPath toFile:remotePath];
}

/*	Basically does the same as asking CK to upload the data, but also deletes existing files first if the Host Setup says to.
 */
- (void)uploadFromData:(NSData *)data toFile:(NSString *)remotePath;
{
	if ([[[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.deletePagesWhenPublishing"] boolValue])
	{
		[myController deleteFile:remotePath];
	}
	
	[myController uploadFromData:data toFile:remotePath];
}

#pragma mark -
#pragma mark Main Methods

- (void)recursivelyCreateDirectoriesFromPath:(NSString *)path setPermissionsOnAllFolders:(BOOL)flag
{
	NSString *pathWithoutTrailingSlash = path;
	NSString *pathWithTrailingSlash = path;
	if ( [path hasSuffix:@"/"] )
	{
		pathWithoutTrailingSlash = [path substringToIndex:[path length] - 1];;
	}
	else
	{
		pathWithTrailingSlash = [path stringByAppendingString:@"/"];
	}
	
	if ( [myPathsCreated containsObject:pathWithTrailingSlash] )
	{
		return;
	}
	
	NSArray *pathComponents = [pathWithoutTrailingSlash componentsSeparatedByString:@"/"];
	NSMutableString *builtupPath = [NSMutableString string];
	
	NSEnumerator *pathEnum = [pathComponents objectEnumerator];
	NSString *curPath;
	while ( curPath = [pathEnum nextObject] ) 
	{
		if (!myKeepPublishing) return;	// exit if we are supposed to stop
		
		[builtupPath appendFormat:@"%@/", curPath];
		
		if ([myPathsCreated containsObject:builtupPath]) continue;
		
		[myController createDirectory:[NSString stringWithString:builtupPath]]; //we don't want to go messing with permissions if someone specifies an absolute path like /User/ghulands/Sites/
		if ( flag )
		{
			[myController setPermissions:myDirectoryPermissions forFile:builtupPath];
		}
		[myPathsCreated addObject:[NSString stringWithString:builtupPath]];
	}
	
	if (!myKeepPublishing) return;
	[myController setPermissions:myDirectoryPermissions forFile:builtupPath];
}

/*	Uploads the specified page and returns by reference the media & resources that it requires
 */
- (void)threadedUploadPage:(KTAbstractPage *)page onlyUploadStalePages:(BOOL)staleOnly
{
	// Fetch the publishing info for the page. Bail if it is not for publishing.
	NSDictionary *publishingInfo = [self performSelectorOnMainThreadAndReturnResult:@selector(publishingInfoForPage:)
																		 withObject:page];
	if (!publishingInfo || (staleOnly && ![publishingInfo boolForKey:@"isStale"]))
	{
		return;
	}
	
	
	// Upload the page itself
	NSString *uploadPath = [[self storagePath] stringByAppendingPathComponent:[publishingInfo objectForKey:@"uploadPath"]];
	
	NSData *pageData = [publishingInfo objectForKey:@"sourceData"];
	if (pageData)
	{
		
		[myUploadedPathsMap setObject:page forKey:uploadPath];
		[self recursivelyCreateDirectoriesFromPath:[uploadPath stringByDeletingLastPathComponent] setPermissionsOnAllFolders:YES];
		[self uploadFromData:pageData toFile:uploadPath];
		[myController setPermissions:myPagePermissions forFile:uploadPath];
	}
	
	
	// Publish the RSS feed if there is one
	NSData *RSSData = [publishingInfo objectForKey:@"RSSData"];
	if (RSSData)
	{
		NSString *RSSFilename = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
		NSString *RSSUploadPath = [[uploadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
		
		[self uploadFromData:RSSData toFile:RSSUploadPath];
		[myController setPermissions:myPagePermissions forFile:RSSUploadPath];
	}
}


/*	Support method for -threadedUploadPage: that is called on the MAIN THREAD.
 *	
 *	Returns a dictionary with the following keys:
 *		sourceData			-	NSData representation of the page's HTML. nil if not for publishing (e.g. Download page)
 *		uploadPath			-	The page's path relative to   docRoot/subFolder/
 *		RSSData				-	If the collection has an RSS feed, its NSData representation
 *		isStale				-	NSNumber copy of the page's isStale attribute
 *	
 *	If the page will not be published because it or a parent is a draft, returns nil.
 */
- (NSDictionary *)publishingInfoForPage:(KTAbstractPage *)page;
{
	// This MUST be called from the main thread
	if (![NSThread isMainThread]) {
		[NSException raise:NSObjectInaccessibleException format:@"-[KTTransferController publishingInfoForPage:] is not thread-safe"];
	}
	
	
	// Bail early if the page is not for publishing
	if ([page isKindOfClass:[KTPage class]] && [(KTPage *)page pageOrParentDraft])
	{
		return nil;
	}
	
	
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:5];
	
	
	// Source data
	if (![page isKindOfClass:[KTPage class]] || [(KTPage *)page shouldPublishHTMLTemplate])
	{
		NSString *pageString = [[page contentHTMLWithParserDelegate:self isPreview:NO] stringByAdjustingHTMLForPublishing];
		KTPage *masterPage = ([page isKindOfClass:[KTPage class]]) ? (KTPage *)page : [page parent];
		NSString *charset = [[masterPage master] valueForKey:@"charset"];
		NSStringEncoding encoding = [charset encodingFromCharset];
		NSData *data = [pageString dataUsingEncoding:encoding allowLossyConversion:YES];
		[info setObject:data forKey:@"sourceData"];
	}
	else if ([[[[page plugin] bundle] bundleIdentifier] isEqualToString:@"sandvox.DownloadElement"])
	{
		// This is currently a special case to make sure Download Page media is published
		// TODO: Generalise this code if any other plugins actually need it
		KTMediaFileUpload *upload = [[page delegate] performSelector:@selector(mediaFileUpload)];
		[self addParsedMediaFileUpload:upload];
	}
		
	[info setObject:[page valueForKey:@"isStale"] forKey:@"isStale"];
	
	
	// Upload path
	[info setObject:[page uploadPath] forKey:@"uploadPath"];
	
	
	// RSS feed
	if ([page isKindOfClass:[KTPage class]] && [page boolForKey:@"collectionSyndicate"] && [(KTPage *)page collectionCanSyndicate])
	{
		NSString *RSSString = [(KTPage *)page RSSRepresentation];
		if (RSSString)
		{
			RSSString = [(KTPage *)page fixPageLinksFromString:RSSString managedObjectContext:(KTManagedObjectContext *)[page managedObjectContext]];
			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			// MAYBE DO THIS TOO IF WE USE SOMETHING OTHER THAN UTF8
			// rssString = [rssString escapeCharactersOutOfCharset:[aPage valueForKeyPath:@"master.charset"]];		
// FIXME: If we specify UTF8 here, won't that get us in trouble?  Should we use other encodings, like of site?
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			[info setObject:RSSData forKey:@"RSSData"];
		}
	}
	
	
	// Return result
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:info];
	return result; 
}


- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if ( NSOKButton == returnCode )
	{
		NSString *stemURL = [[oExportURL stringValue] trimFirstLine];
		if ( (nil != stemURL) && ![stemURL isEqualToString:@""] )
		{
			KTHostProperties *hostProperties = [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties"];
			[hostProperties setValue:stemURL forKey:@"stemURL"];
		}
		
		[self setDocumentRoot:[sheet filename]];
		[self setSubfolder:nil];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		(void) [fm createDirectoryAtPath:[sheet filename] attributes:nil];
		
		[self performSelector:@selector(uploadEverythingToSuggestedPath:) 
				   withObject:[sheet filename] 
				   afterDelay:0.0];	// try again, now with a path
	}
	else
	{
		[[[self associatedDocument] windowController] setPublishingMode:kGeneratingPreview];
		[self resumeUIUpdates];
		//[[[[self associatedDocument] windowController] webViewController] setSuspendNextWebViewUpdate:DONT_SUSPEND];
	}
}

- (void)savePanelForStaleUploadDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if ( NSOKButton == returnCode )
	{
		[self setDocumentRoot:[sheet filename]];
		[self setSubfolder:nil];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		(void) [fm createDirectoryAtPath:[sheet filename] attributes:nil];
		
		[self performSelector:@selector(uploadStaleAssetsToSuggestedPath:) 
				   withObject:[sheet filename] 
				   afterDelay:0.0];	// try again, now with a path
	}
	else
	{
		[[[self associatedDocument] windowController] setPublishingMode:kGeneratingPreview];
		[self resumeUIUpdates];
		//[[[[self associatedDocument] windowController] webViewController] setSuspendNextWebViewUpdate:DONT_SUSPEND];
	}
}

- (BOOL)panel:(NSSavePanel *)sender isValidFilename:(NSString *)filename
{
	if ( nil == [sender accessoryView] ) return YES;
		
	// We only use this method to make sure the Site URL is okay.
	NSString *initialStemURL = [[oExportURL stringValue] trimFirstLine];
	NSMutableString *stemURL = [NSMutableString stringWithString:initialStemURL];
	NSString *username = [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.userName"];
	
	//make sure it is valid
	if (![stemURL hasPrefix:@"http"]) //we could be publishing to https so just test for http.
	{
		[stemURL insertString:@"http://" atIndex:0];
	}
	if (![stemURL hasSuffix:@"/"])
	{
		[stemURL appendString:@"/"];
	}
	if ( nil != username )
	{
		[stemURL replaceOccurrencesOfString:@"?" 
								 withString:username
									options:NSLiteralSearch
									  range:NSMakeRange(0, [stemURL length])];
	}
	NSURL *testURL = [NSURL URLWithString:[stemURL encodeLegally]];
	NSString *urlHost = [testURL host];
	
	//test to see if we have the username in the host somewhere
	NSArray *hostbits = [urlHost componentsSeparatedByString:@"."];
	BOOL validHostName = [hostbits count] > 1;
	
	//Check it is a valid URL
	if ( (nil == testURL) || !validHostName )
	{
		[oBadSiteURL setHidden:NO];
		[sender makeKeyAndOrderFront:self];
		[sender makeFirstResponder:oExportURL];
		[oExportURL selectText:self];
		return NO;
	}
	
	if ( ![stemURL isEqualToString:initialStemURL] )	// changed; fix it!
	{
		/// defend against nil
		if (nil == stemURL) stemURL = @"";
		[oExportURL performSelector:@selector(setStringValue:) withObject:stemURL afterDelay:0.0];
		return NO;		// only way to replace and stop it .. though now we are OK!
	}
	
	return YES;
} 


- (void)uploadEverything
{
	[self uploadEverythingToSuggestedPath:nil];
}

- (void)uploadEverythingToSuggestedPath:(NSString *)aSuggestedPath
{
	[myUploadedPathsMap removeAllObjects];
	[self clearUploadedDesigns];
	[self removeAllParsedResources];
	[self removeAllGraphicalTextBlocks];
	[self removeAllParsedMediaFileUploads];
	[self removeAllMediaFileUploads];
	
	BOOL hasRSSFeeds = [[self associatedDocument] hasRSSFeeds];
	BOOL hasGoogleSiteMap = [[[self associatedDocument] documentInfo] boolForKey:@"generateGoogleSiteMap"];
	
	// Make sure we can upload somewhere. Select path if not.
	if (kGeneratingRemoteExport ==  [self where]
		&& (nil == [self storagePath] 
			|| (hasRSSFeeds && [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.stemURL"] == nil) ) )
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		[savePanel setMessage:NSLocalizedString(@"Please create a folder to contain your site.", @"prompt for exporting a website to a folder")];
		[savePanel setDelegate:self];
		
		if (( !hasRSSFeeds && !hasGoogleSiteMap) || [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.remoteSiteURL"])
		{
			[oExportURL setStringValue:@""];		// no export URL showing, so don't put in a value
		}
		else	// no URL, so show the accessory panel
		{
			[savePanel setAccessoryView:oExportPanelAccessoryView];		// only show the accessory view if the folder is missing
			[oBadSiteURL setHidden:YES];
			[oExportURL setDelegate:self];
		}
		
		[savePanel beginSheetForDirectory:[aSuggestedPath stringByDeletingLastPathComponent]
									 file:[aSuggestedPath lastPathComponent]
						   modalForWindow:[[[self associatedDocument] windowController] window]
							modalDelegate:self
						   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
							  contextInfo:nil];
		// [savePanel makeFirstResponder:oExportURL];
		return;	// don't do it now, do it when we're done
	}
	
	if ([self where] == kGeneratingRemoteExport)
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Exporting", @"upload prefix")];
	}
	else if ([self where] == kGeneratingLocal)
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Saving", @"upload prefix")];
	}
	else
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Uploading", @"upload prefix")];
	}
	// Note: mounted file systems may want something else?
	
	if ([self connection])	// attempt to get connection -- only proceed if we got a connection.
	{

		myInspectorWasDisplayed = [[[KTInfoWindowController sharedControllerWithoutLoading] window] isVisible];
		[[[KTInfoWindowController sharedControllerWithoutLoading] window] orderOut:self];
			
		//force the connection creation on  the main thread
		[(AbstractConnection *)[self connection] setTranscript:[[KTTranscriptController sharedControllerWithoutLoading] textStorage]];
		//[[[self associatedDocument] windowController] cancelFireUpdateElementTimer];
		[[self associatedDocument] suspendAutosave];
		mySuspended = YES;

		myKeepPublishing = YES;
		NSArray *args;
		if (aSuggestedPath)
			args = [NSArray arrayWithObject:aSuggestedPath];
		else
			args = [NSArray array];
		myContentAction = [[NSInvocation invocationWithSelector:@selector(threadedUploadEverythingToPath:) 
														 target:self
													  arguments:args] retain];
		[self showIndeterminateProgressWithStatus:NSLocalizedString(@"Preparing to Publish Website...", @"message for progress window")];
	}
}

- (BOOL)threadedUploadEverythingToPath:(NSString *)aSuggestedPath
{
	BOOL result = NO;
	[self threadedPrepareHostForUpload];
	
	
	// Run through each page, performing the upload & building the list of required resources.
	NSArray *allPages = [self performSelectorOnMainThreadAndReturnResult:@selector(pagesToParse)];
	@try
	{
		NSEnumerator *pagesEnumerator = [allPages objectEnumerator];
		KTAbstractPage *aPage;
		
		while (aPage = [pagesEnumerator nextObject])
		{
			myHadFilesToUpload = YES;
			[self threadedUploadPage:aPage onlyUploadStalePages:NO];
		}
			
	
		// Upload the design - in the future there may be more than one - and master.css
		NSDictionary *designPublishingInfo = [self performSelectorOnMainThreadAndReturnResult:@selector(siteDesignPublishingInfo)];
		KTDesign *design = [designPublishingInfo objectForKey:@"design"];
		[self threadedUploadDesign:design];
		
		NSString *masterCSS = [designPublishingInfo objectForKey:@"masterCSS"];
		if (masterCSS)
		{
			NSData *masterCSSData = [[masterCSS normalizeUnicode] dataUsingEncoding:NSUTF8StringEncoding
															   allowLossyConversion:YES];
			
			NSString *designUploadPath = [[self storagePath] stringByAppendingPathComponent:[design remotePath]];
			NSString *masterCSSUploadPath = [designUploadPath stringByAppendingPathComponent:@"master.css"];
			
			[self uploadFromData:masterCSSData toFile:masterCSSUploadPath];
		}
				
		
		// Upload the resources
		[self threadedUploadResources:[self parsedResources]];
		
		
		// Upload media
		[self threadedUploadMediaFiles:[self parsedMediaFileUploads]];
		
	}
	@finally
	{
	}
	
	
	result = YES;
	return result;
	
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
			
	@try
	{
		myHadFilesToUpload = YES;	// uploading everything so clearly there were things to upload
						
		[[[self associatedDocument] windowController] setPublishingMode:[self where]];
		
		NSManagedObjectContext *moc = [[self associatedDocument] managedObjectContext];
		KTPage *root = [moc root];
		
		if ( !myKeepPublishing )
		{
			// cleanup!
			return NO; // @finally will still be executed
		}
		
		if ( kGeneratingRemoteExport != [self where] )
		{
			[self recursivelyCreateDirectoriesFromPath:[self storagePath] setPermissionsOnAllFolders:NO];
		}
		if ( !myKeepPublishing )
		{
			// cleanup!
			return NO; // @finally will still be executed
		}
//	TODO:	Need to heed sitemap flag
		// Upload the Google Site Map
		if ([root boolForKey:@"addBool2"])	// Should be using @"generateGoogleSiteMap"
		{
			NSString *googleSiteMap = [[self associatedDocument] generatedGoogleSiteMapWithManagedObjectContext:(KTManagedObjectContext *)moc];
			NSData *siteMapData = [googleSiteMap dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			NSData *gzipped = [siteMapData compressGzip];
			NSString *siteMapPath = [[self storagePath] stringByAppendingPathComponent:@"sitemap.xml.gz"];
			[self uploadFromData:gzipped toFile:siteMapPath];

			if ([self where] != kGeneratingRemoteExport) // don't ping google if we are just exporting
			{
				NSString *siteMapURLString = [[[self associatedDocument] publishedSiteURL] stringByAppendingString:@"/sitemap.xml.gz"];
				NSString *pingURLString = [NSString stringWithFormat:@"http://www.google.com/webmasters/tools/ping?sitemap=%@",
					[siteMapURLString urlEncode]];
				[self pingThisURLString:pingURLString];
			}
		}
		if ( !myKeepPublishing )
		{
			// cleanup!
			return NO; // @finally will still be executed
		}
		
		
		
		if ([self where] == kGeneratingRemoteExport) {
			// Put the warning file in there.  This will actually happen first....
			NSString *infoFileName = NSLocalizedString(@"_EXPORT INFORMATION_.txt", @"obvious warning string for file name, starts with _ for alphabetical sorting");
			
			NSString *message = [NSString stringWithFormat:NSLocalizedString(@"This was exported on %@\n\n", @"followed by date"), [NSCalendarDate date]];
			
			NSString *remoteSiteURL = [[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.remoteSiteURL"];
			if (nil != remoteSiteURL && ![remoteSiteURL isEqualToString:@""])
			{
				message = [message stringByAppendingFormat:NSLocalizedString(@"These files should be uploaded so that they can be viewed at <%@>.\n\n", @""), remoteSiteURL];
			}

			if (![[[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.PathsWithIndexPages"] boolValue])	// warn about folders ending in "/"
			{
				message = [message stringByAppendingString:NSLocalizedString(@"If you open your pages directly from the Finder, please be warned that some hyperlinks that you follow will open folders from the Finder, instead of the corresponding collection pages. This is a known behavior of Safari.",@"")];
			}
			NSString *messageFilePath = [[self storagePath] stringByAppendingPathComponent:infoFileName];
			BOOL wrote = [[message dataUsingEncoding:NSUnicodeStringEncoding] writeToFile:messageFilePath atomically:NO];
			BOOL changed = [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:messageFilePath];
			LOG((@"%@ wrote = %d changed = %d", NSStringFromSelector(_cmd), wrote, changed));
		}
		myHadFilesToUpload = YES;
	}
	@catch (NSException *exception)
	{
		NSLog(@"%@ %@", NSStringFromSelector(_cmd), exception);
	}
	@finally	// clean up now that we are doing exporting.  We do this here because the export
				// may have been done asynchronously -- see savePanelDidEnd:
	{
		//[[context persistentStoreCoordinator] unlock];
		[[self associatedDocument] resumeAutosave];
		[[self associatedDocument] suspendAutosave];

		if (!myKeepPublishing)	// did we cancel?
		{
			// Now actually do the cleanup
			[self performSelectorOnMainThread:@selector(finishTransferAndCloseSheet:) withObject:nil waitUntilDone:NO];
		}
		
		result = myKeepPublishing;
		[pool release];
	}
	return result;
}

- (void)uploadStaleAssets
{
	[self uploadStaleAssetsToSuggestedPath:nil];
}

- (void)uploadStaleAssetsToSuggestedPath:(NSString *)aSuggestedPath
{
	[myUploadedPathsMap removeAllObjects];
	[self clearUploadedDesigns];
	[self removeAllParsedResources];
	
	// Make sure we can upload somewhere. Select path if not.
	if (kGeneratingRemoteExport ==  [self where] && nil == [self storagePath])
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		[savePanel setMessage:NSLocalizedString(@"Please create a folder to contain your site.", @"prompt for exporting a website to a folder")];
		
		[savePanel beginSheetForDirectory:[aSuggestedPath stringByDeletingLastPathComponent]
									 file:[aSuggestedPath lastPathComponent]
						   modalForWindow:[[[self associatedDocument] windowController] window]
							modalDelegate:self
						   didEndSelector:@selector(savePanelForStaleUploadDidEnd:returnCode:contextInfo:)
							  contextInfo:nil];
		return;	// don't do it now, do it when we're done
	}
	
	if ([self where] == kGeneratingRemoteExport)
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Exporting", @"upload prefix")];
	}
	else if ([self where] == kGeneratingLocal)
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Saving", @"upload prefix")];
	}
	else
	{
		[myController setUploadingStatusPrefix:NSLocalizedString(@"Uploading", @"upload prefix")];
	}
	
	if ([self connection])	// attempt to get connection -- only proceed if we got a connection.
	{
		myInspectorWasDisplayed = [[[KTInfoWindowController sharedControllerWithoutLoading] window] isVisible];
		[[[KTInfoWindowController sharedControllerWithoutLoading] window] orderOut:self];
		
		//[[[[self associatedDocument] windowController] webViewController] setSuspendNextWebViewUpdate:SUSPEND];		// suspend until further notice
		[self suspendUIUpdates];

		[(AbstractConnection *)[self connection] setTranscript:[[KTTranscriptController sharedControllerWithoutLoading] textStorage]];
		
		//[[[self associatedDocument] windowController] cancelFireUpdateElementTimer];
		[[self associatedDocument] suspendAutosave];
		mySuspended = YES;
		
		myKeepPublishing = YES;
		NSArray *args;
		if (aSuggestedPath)
			args = [NSArray arrayWithObject:aSuggestedPath];
		else
			args = [NSArray array];
		
		myContentAction = [[NSInvocation invocationWithSelector:@selector(threadedUploadStaleAssetsToPath:)
														 target:self
													  arguments:args] retain];
		
		[self showIndeterminateProgressWithStatus:NSLocalizedString(@"Preparing to Publish...", @"Uploading")];
	}
}

- (BOOL)threadedUploadStaleAssetsToPath:(NSString *)path
{
	BOOL result = NO;
	[self threadedPrepareHostForUpload];
	
	
	// Get the list of all pages in the site. We fetch just stale pages, but that might not catch all stale media
	NSArray *allPages = [self performSelectorOnMainThreadAndReturnResult:@selector(pagesToParse)];
	@try
	{
		// Run through each page, performing the upload & building the list of required resources.
		NSEnumerator *pagesEnumerator = [allPages objectEnumerator];
		KTPage *aPage;
		
		while (aPage = [pagesEnumerator nextObject])
		{
			myHadFilesToUpload = YES;
			[self threadedUploadPage:aPage onlyUploadStalePages:YES];
		}
			
	
		// Upload the design if its published version is different to the current one
		NSDictionary *designPublishingInfo = [self performSelectorOnMainThreadAndReturnResult:@selector(siteDesignPublishingInfo)];
		KTDesign *design = [designPublishingInfo objectForKey:@"design"];
		if (![[design version] isEqualToString:[designPublishingInfo objectForKey:@"versionLastPublished"]])
		{
			[self threadedUploadDesign:design];
		}
		
				
		// Upload Master-specific CSS
		NSString *masterCSS = [designPublishingInfo objectForKey:@"masterCSS"];
		if (masterCSS)
		{
			NSData *masterCSSData = [[masterCSS normalizeUnicode] dataUsingEncoding:NSUTF8StringEncoding
															   allowLossyConversion:YES];
			
			NSString *designUploadPath = [[self storagePath] stringByAppendingPathComponent:[design remotePath]];
			NSString *masterCSSUploadPath = [designUploadPath stringByAppendingPathComponent:@"master.css"];
			
			[self uploadFromData:masterCSSData toFile:masterCSSUploadPath];
		}
				
		
		
		// Upload the resources
		[self threadedUploadResources:[self parsedResources]];
		
		
		// Upload media
		NSSet *staleMedia = [self performSelectorOnMainThreadAndReturnResult:@selector(staleParsedMediaFileUploads)];
		[self threadedUploadMediaFiles:staleMedia];
		
	}
	@finally
	{
	}
	
	
	result = YES;
	return result;
}

#pragma mark support

/*	Support method shared by both Publish Changes and Publish Entire Site
 */
- (void)threadedPrepareHostForUpload
{
	[[[self associatedDocument] windowController] setPublishingMode:[self where]];
	
	
	// Create the docRoot and subfolder first
	if ([self where] != kGeneratingRemoteExport)
	{
		[self recursivelyCreateDirectoriesFromPath:[self documentRoot] setPermissionsOnAllFolders:NO];
		[self recursivelyCreateDirectoriesFromPath:[self storagePath] setPermissionsOnAllFolders:YES];
	}
}

/*	Support method to return a list of the pages due to be parsed before publishing.
 *	Normally this is every page within the site, but if the user is running the demo return just the home page
 */
- (NSArray *)pagesToParse
{
	NSAssert1([NSThread isMainThread], @"%@ is not thread-safe", NSStringFromSelector(_cmd));
	
	NSArray *result = nil;
	if (!gLicenseIsBlacklisted && (nil != gRegistrationString))	// License is OK
	{
		result = [KTAbstractPage allPagesInManagedObjectContext:[[self associatedDocument] managedObjectContext]];
	}
	else
	{
		result = [NSArray arrayWithObject:[[self associatedDocument] root]];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Design

/*	Uploads the specified design.
 *	The design is added to the list of designs published, accessible via [self uploadedDesigns]
 */
- (void)threadedUploadDesign:(KTDesign *)design
{
	NSString *uploadDirectory = [[self storagePath] stringByAppendingPathComponent:[design remotePath]];
	[myController createDirectory:uploadDirectory permissions:myDirectoryPermissions];
	
	
	// Upload the design's resources
	NSSet *resources = [design resourceFiles];
	NSEnumerator *resourcesEnumerator = [resources objectEnumerator];
	NSString *aResource;
	while ( (aResource = [resourcesEnumerator nextObject]) && myKeepPublishing )
	{
		NSString *uploadPath = [uploadDirectory stringByAppendingPathComponent:[aResource lastPathComponent]];
		[self uploadFile:aResource toFile:uploadPath];
		[myController setPermissions:myPagePermissions forFile:uploadPath];
	}
	
	// Mark the design as being uploaded
	[myUploadedDesigns addObject:design];
}

/*	A dictionary with the information needeed to publish the main site design.
 *	The keys are:
 *		design					-	The KTDesign object
 *		versionLastPublished	-	The version of the design that was last published
 *		masterCSS				-	The custom CSS specific to the main KTMaster object
 */
- (NSDictionary *)siteDesignPublishingInfo
{
	NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:2];
	
	KTPage *root = [[[self document] managedObjectContext] root];
	KTMaster *master = [root master];
	
	// Design
	KTDesign *design = [master design];
	[info setObject:design forKey:@"design"];
	
	
	// Version
	NSString *versionLastPublished = [master valueForKeyPath:@"designPublishingInfo.versionLastPublished"];
	[info setValue:versionLastPublished forKey:@"versionLastPublished"];	// Accounts for a nil version
	
	
	// Master CSS. Inform of the banner image (if there is one) & graphical text.
	NSString *masterCSS = [master masterCSSForPurpose:kGeneratingRemote];
	
	KTMediaFile *bannerImage = [[master bannerImage] file];
	if (bannerImage)
	{
		[self addParsedMediaFileUpload:[bannerImage defaultUpload]];
	}
	
	NSDictionary *graphicalTextBlocks = [self graphicalTextBlocks];
	if (graphicalTextBlocks && [graphicalTextBlocks count] > 0)
	{
		if (!masterCSS) masterCSS = @"";
		
		// Add on CSS for each block
		NSEnumerator *textBlocksEnumerator = [graphicalTextBlocks keyEnumerator];
		NSString *aGraphicalTextID;
		while (aGraphicalTextID = [textBlocksEnumerator nextObject])
		{
			KTWebViewTextBlock *aTextBlock = [graphicalTextBlocks objectForKey:aGraphicalTextID];
			KTMediaFile *aGraphicalText = [[aTextBlock graphicalTextMedia] file];
			
			NSString *path = [[NSBundle mainBundle] overridingPathForResource:@"imageReplacementEntry" ofType:@"txt"];
			
			NSMutableString *CSS = [NSMutableString stringWithContentsOfFile:path usedEncoding:NULL error:NULL];
			[CSS replace:@"_UNIQUEID_" with:aGraphicalTextID];
			[CSS replace:@"_WIDTH_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"width"]]];
			[CSS replace:@"_HEIGHT_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"height"]]];
			
			NSString *baseMediaPath = [[aGraphicalText defaultUpload] valueForKey:@"pathRelativeToSite"];
			NSString *mediaPath = [@".." stringByAppendingPathComponent:baseMediaPath];
			[CSS replace:@"_URL_" with:mediaPath];
			
			masterCSS = [masterCSS stringByAppendingString:CSS];
		}
	}
	
	[info setValue:masterCSS forKey:@"masterCSS"];
	
	
	// Tidy up and return
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:info];
	[info release];
	return result;
}

#pragma mark -
#pragma mark Resources

/*	Creates the _Resources directory and then publishes the specified resources to it.
 */
- (void)threadedUploadResources:(NSSet *)resources
{
	// Create the resources directory
	NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
	NSString *resourcesDirectoryPath = [[self storagePath] stringByAppendingPathComponent:resourcesDirectoryName];
	[myController createDirectory:resourcesDirectoryPath permissions:myDirectoryPermissions];
	
	
	// Upload the resource files
	NSEnumerator *resourcesEnumerator = [resources objectEnumerator];
	NSString *aResourceSourcePath;
	while (aResourceSourcePath = [resourcesEnumerator nextObject])
	{
		if (!myKeepPublishing) {	// Bail if requested
			return;
		}
		
		NSString *aResourceFilename = [aResourceSourcePath lastPathComponent];
		NSString *aResourceUploadPath = [resourcesDirectoryPath stringByAppendingPathComponent:aResourceFilename];
		[self uploadFile:aResourceSourcePath toFile:aResourceUploadPath];
		[myController setPermissions:myPagePermissions forFile:aResourceUploadPath];
	}
}

- (NSSet *)parsedResources { return [NSSet setWithSet:myParsedResources]; }

- (void)removeAllParsedResources { [myParsedResources removeAllObjects]; }

#pragma mark -
#pragma mark ConnectionController Delegate

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Uploading_using_SFTP";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (id <AbstractConnectionProtocol>)transferControllerNeedsConnection:(CKTransferController *)controller createIfNeeded:(BOOL)aCreate
{
	if (aCreate)
	{
		return [self connection];
	}
	else
	{
		return myConnection;	// don't create, just return connection that may exists
	}
}

- (BOOL)transferControllerNeedsContent:(CKTransferController *)controller
{
	[controller setStatusMessage:NSLocalizedString(@"Generating Content...", "message")];

	[myContentAction invoke];
	
	BOOL result = NO;
	[myContentAction getReturnValue:&result];
	return result;							// Success
}

// called when done generating, or when we want to stop generation
- (void)transferControllerFinishedContentGeneration:(CKTransferController *)controller completed:(BOOL)aFlag
{
	myKeepPublishing = NO;	// we don't want this flag anymore, since when it is YES, it means we are generating content.
}

// Returns whether or not to close the window.  In this case, doesn't close the window; we will take care of that in finishTransferAndCloseSheet.
- (BOOL)transferControllerDefaultButtonAction:(CKTransferController *)controller
{
	NSAssert([NSThread isMainThread], @"should be main thread");
	
	if (myKeepPublishing)
	{
		[myController setStatusMessage:NSLocalizedString(@"Stopping...", "Transfer Controller")];
		myKeepPublishing = NO;		// signal to content generation to stop
		[myController requestStopTransfer];
	}
	else 
	{
		if (mySuspended)	// are we still publishing?  If so, we need to stop the connection
		{
			[myController stopTransfer];	// this will cause the callback that resumes autosave
		}
		[self finishTransferAndCloseSheet:self];
	}
	return NO;
}

// Open the published web page.

- (BOOL)transferControllerAlternateButtonAction:(CKTransferController *)controller
{
	if (myPublishedURL != nil) {
		NSURL *url = [NSURL URLWithString:[myPublishedURL encodeLegally]];
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
	}
	return NO;
}


- (void)transferControllerDidFinish:(CKTransferController *)controller returnCode:(CKTransferControllerStatus)code
{
	[[[self associatedDocument] windowController] setPublishingMode:kGeneratingPreview];
		
	myKeepPublishing = NO;
	[[self associatedDocument] resumeAutosave];	// balance to upload...toSuggestedPath
	mySuspended = NO;
	
	NSAssert([NSThread isMainThread], @"should be main thread"); // if not, we have to make sure UI calls are performed on main thread
	
	[myController setDefaultButtonTitle:NSLocalizedString(@"OK", @"OK")];

	if (code == CKFatalErrorStatus)
	{
		[myController setTitle:NSLocalizedString(@"Unable to Publish",@"title of dialog")];
		[myController setStatusMessage:@""];
		[myController setAlternateButtonTitle:nil];
		NSAlert *a = [NSAlert alertWithError:[myController fatalError]];
		[a runModal];
	}

	if (myHadFilesToUpload && CKSuccessStatus == code)
	{
		/*	
		If we transferred the same number of files as we queued, then we know the transfer wasn't cancelled.
		 We could add a parameter to the abstract connections upload methods to take a userInfo object that 
		 correlates to the upload and handle it in the uploadDidFinish: method. Maybe post 1.0. In the mean 
		 time we just set the whole document as not being stale.
		 
		 We never get here unless we have completed everything in the transfer queue
		 */
		[myController setProgress:-1];
		[myController setStatusMessage:NSLocalizedString(@"Finishing...", @"transfer controller")];
		
		
		
		// Generate the published url
		if ( [self where] == kGeneratingRemote )
		{
			[myPublishedURL autorelease];
			myPublishedURL = [[[self associatedDocument] valueForKeyPath:@"documentInfo.hostProperties.remoteSiteURL"] retain];
		}
		else if ( [self where] == kGeneratingLocal )
		{
			// user or apache dir
			NSString *url = [NSString stringWithString:@"/localhost/"];
			NSString *apache = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApacheDocRoot"];
			NSString *local = [[NSWorkspace sharedWorkspace] userSitesDirectory];
			
			if ( [[self storagePath] hasPrefix:apache] )
			{
				url = [url stringByAppendingPathComponent:[[self storagePath] substringFromIndex:[apache length]]];
			}
			else
			{
				url = [url stringByAppendingPathComponent:[NSString stringWithFormat:@"~%@", NSUserName()]];
				url = [url stringByAppendingPathComponent:[[self storagePath] substringFromIndex:[local length]]];
			}
			
			if ( ![url hasPrefix:@"/"] )
			{
				url = [@"/" stringByAppendingString:url];
			}
			url = [@"http:/" stringByAppendingString:url];
			
			[myPublishedURL autorelease];
			myPublishedURL = [[NSString alloc] initWithString:url];
		}
		
		BOOL hadErrors = [myController hadErrorsTransferring];
		if ( [self where] == kGeneratingRemoteExport )
		{
			[myController setTitle:NSLocalizedString(@"Export Complete", "Transfer Controller")];
			if (hadErrors)
			{
				[myController setStatusMessage:NSLocalizedString(@"Warning: Sandvox was not able to verify that all files were saved. Please check the folder for accuracy. You may wish to Export again.", "Transfer Controller")];
			}
			else
			{
				[myController setStatusMessage:@""];
			}
		}
		else
		{
			[myController setTitle:NSLocalizedString(@"Publishing Complete", "Transfer Controller")];
			if (hadErrors)
			{
				[myController setStatusMessage:NSLocalizedString(@"Warning: Sandvox was not able to verify that all files were uploaded. Please check your site for accuracy. You may wish to Publish Entire Site again.", "Transfer Controller")];
			}
			else
			{
				NSString *message = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"The site has been published to", "Transfer Controller"), [[self connection] host]];
				[myController setStatusMessage:message];
			}
		}
		
		[myController setFinished];
		
		// enable View Site if we are remote
		if ( [self where] != kGeneratingRemoteExport) 
		{
			[myController setAlternateButtonTitle:NSLocalizedString(@"View Site", @"button name")];
		}
		
		// growl support
		if ( ![[[[self associatedDocument] windowController] window] isMainWindow] )
		{
			if ( [self where] == kGeneratingRemoteExport )
			{
				[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Export Complete", "Growl notification")
											description:NSLocalizedString(@"Your site has been exported", "Growl notification")
									   notificationName:NSLocalizedString(@"Export Complete", "Growl notification")
											   iconData:nil
											   priority:1
											   isSticky:NO
										   clickContext:nil];
			}
			else
			{
				if ( ![[NSApplication sharedApplication] isActive] )
				{
					[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Publishing Complete", @"Growl notification")
												description:[NSString stringWithFormat:NSLocalizedString(@"Your site has been published to %@", @"Growl notification"), [[self connection] host]]
										   notificationName:NSLocalizedString(@"Publishing Complete", @"Growl notification")
												   iconData:nil
												   priority:1
												   isSticky:NO
											   clickContext:myPublishedURL];
				}
			}
		}
		
		
		// Unless this was an export, update staleness etc. to reflect that
		if ( [self where] != kGeneratingRemoteExport )
		{
			// Mark published pages as non-stale (Safe since this should be the main thread)
			NSArray *publishedPages = [myUploadedPathsMap allValues];
			[publishedPages setBool:NO forKey:@"isStale"];
			
			// Record the app version published with
			NSManagedObject *hostProperties = [[[self associatedDocument] documentInfo] valueForKey:@"hostProperties"];
			[hostProperties setValue:[[NSBundle mainBundle] version] forKey:@"publishedAppVersion"];
			[hostProperties setValue:[NSString stringWithFormat:@"%d", [[NSBundle mainBundle] buildVersion]] forKey:@"publishedAppBuildVersion"];
			
			// Record the version of the designs that were published
			NSSet *publishedDesigns = [self uploadedDesigns];
			[publishedDesigns makeObjectsPerformSelector:@selector(didPublishInDocument:) withObject:[self associatedDocument]];
			
			// Mark published media as non-stale
			NSSet *publishedMedia = [self mediaFileUploads];
			[publishedMedia setBool:NO forKey:@"isStale"];
		}
		
		
		
		
		// turn the document UI back on
		[self resumeUIUpdates];
		//[[[[self associatedDocument] windowController] webViewController] setSuspendNextWebViewUpdate:DONT_SUSPEND];		// restore
		
	}
	else if (!myHadFilesToUpload)
	{
		[myController setFinished];
		
		[myController setStatusMessage:NSLocalizedString(@"No changes need publishing", @"message for progress window")];
	
		[myController setDefaultButtonTitle:NSLocalizedString(@"OK", @"change cancel button to ok")];
		[myController setAlternateButtonTitle:nil];
	}
}

#pragma mark -
#pragma mark HTML Parser

- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSString *)resourcePath
{
	[myParsedResources addObject:resourcePath];
}

- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
{
	// Add the upload to our list
	if (upload)
	{
		[self addParsedMediaFileUpload:upload];
	}
}

/*	Upload graphical text media
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTWebViewTextBlock *)textBlock
{
	KTMediaFileUpload *upload = [[[textBlock graphicalTextMedia] file] defaultUpload];
	if (upload)
	{
		[self addGraphicalTextBlock:textBlock];
		[self addParsedMediaFileUpload:upload];
	}
}

#pragma mark -
#pragma mark Accessors

- (KTDocument *)associatedDocument
{
    return myAssociatedDocument; 
}

- (void)setAssociatedDocument:(KTDocument *)anAssociatedDocument
{
    [anAssociatedDocument retain];
    [myAssociatedDocument release];
    myAssociatedDocument = anAssociatedDocument;
}

- (int)where { return myWhere; }

- (void)setWhere:(int)aWhere { myWhere = aWhere; }

- (NSSet *)uploadedDesigns { return [NSSet setWithSet:myUploadedDesigns]; }

- (void)clearUploadedDesigns { [myUploadedDesigns removeAllObjects]; }

#pragma mark paths

- (NSString *)documentRoot { return myDocumentRoot; }

- (void)setDocumentRoot:(NSString *)docRoot
{
	// Don't let there be an empty storage path, must start at root
	if ([docRoot isEqualToString:@""])
	{
		docRoot = @"/";
	}
    
	docRoot = [docRoot copy];
	[myDocumentRoot release];
	myDocumentRoot = docRoot;
}

- (NSString *)subfolder { return mySubfolder; }

- (void)setSubfolder:(NSString *)subfolder
{
	subfolder = [subfolder copy];
	[mySubfolder release];
	mySubfolder = subfolder;
}

- (NSString *)storagePath
{
	NSString *result = [[self documentRoot] stringByAppendingPathComponent:[self subfolder]];
	return result;
}

#pragma mark graphical text

- (NSDictionary *)graphicalTextBlocks
{
	return myParsedGraphicalTextBlocks;
}

- (void)addGraphicalTextBlock:(KTWebViewTextBlock *)textBlock
{
	NSString *ID = [NSString stringWithFormat:@"graphical-text-%@", [[textBlock graphicalTextMedia] identifier]];
	[myParsedGraphicalTextBlocks setObject:textBlock forKey:ID];
}

- (void)removeAllGraphicalTextBlocks
{
	[myParsedGraphicalTextBlocks removeAllObjects];
}

#pragma mark -
#pragma mark Progress Panel

- (void)finishTransferAndCloseSheet:(id)sender
{
	if (mySuspended)		// just in case we got here and autosave is suspended
	{
		[myController stopTransfer];	// this will cause the callback that resumes autosave
	}
	//we explicitly release the connection so we know we start each transfer session fresh.
	[self setConnection:nil];
	[[[self associatedDocument] windowController] setPublishingMode:kGeneratingPreview];
	[[KTApplication sharedApplication] endSheet:[myController window]];
	[[myController window] orderOut:self];
	
	[myFilesTransferred removeAllObjects];
	[myPathsCreated removeAllObjects];
	[myUploadedPathsMap removeAllObjects];
	[self clearUploadedDesigns];
	[self removeAllParsedResources];
	[self removeAllGraphicalTextBlocks];
	[self removeAllParsedMediaFileUploads];
	[self removeAllMediaFileUploads];
	
	myPanelIsDisplayed = NO;
	[self resumeUIUpdates];
	//[[[[self associatedDocument] windowController] webViewController] setSuspendNextWebViewUpdate:DONT_SUSPEND];		// restore
																									//we need to reactivate the autosave just in case	
	if (myInspectorWasDisplayed)
	{
		[[[KTInfoWindowController sharedController] window] orderFront:self];
	}
}

- (void)showIndeterminateProgressWithStatus:(NSString *)msg
{	
	NSAssert([NSThread isMainThread], @"should be main thread");
	
	if ([self connection])
	{
		[myController setProgress:-1];
		if ([self where] == kGeneratingRemoteExport)
		{
			[myController setTitle:NSLocalizedString(@"Exporting...", @"Publishing Panel")];
		}
		else
		{
			[myController setTitle:[NSString stringWithFormat:@"%@ %@...", NSLocalizedString(@"Publishing to", @"Transfer controller panel"), [myConnection host]]];
		}
		[myController setAlternateButtonTitle:nil];
		[myController setDefaultButtonTitle:NSLocalizedString(@"Stop", @"transfer panel button name")];
		[myController setStatusMessage:msg];
		
		if (!myPanelIsDisplayed)
		{
			[myController beginSheetModalForWindow:[[[self associatedDocument] windowController] window]];
			[NSApp cancelUserAttentionRequest:NSCriticalRequest];
			myPanelIsDisplayed = YES;
		}
		
		[[self window] makeKeyWindow];
	}
}

#pragma mark -
#pragma mark Growl Delegate Methods

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *strings = [NSArray arrayWithObjects:
		NSLocalizedString(@"Publishing Complete", @"Growl notification"), 
		NSLocalizedString(@"Export Complete", @"Growl notification"), nil];
	[dict setObject:strings
			 forKey:GROWL_NOTIFICATIONS_ALL];
	[dict setObject:strings
			 forKey:GROWL_NOTIFICATIONS_DEFAULT];
	return dict;
}

- (NSString *) applicationNameForGrowl
{
	return [NSApplication applicationName];
}

- (void) growlIsReady
{
	myDoGrowl = YES;
}

- (void)growlNotificationWasClicked:(id)clickContext
{
	/// rewrote to use more cautious, Karelia form
	if ( [clickContext isKindOfClass:[NSString class]] )
	{
		NSString *URLString = [clickContext encodeLegally];
		if ( (nil != URLString) && ![URLString isEqualToString:@""] )
		{
			NSURL *URL = [NSURL URLWithString:URLString];
			if ( nil != URL )
			{
				(void)[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
			}
		}
	}
}

- (void) growlNotificationTimedOut:(id)clickContext
{
	//we don't care
}

#pragma mark -
#pragma mark Pinging

// asynchronously ping by launching curl.

- (void)pingThisURLString:(NSString *)aURLString;
{
	NSArray *args = [NSArray arrayWithObject:aURLString];
	
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/curl"];
	[task setArguments:args];
#ifndef DEBUG
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	[task setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
	[task launch];
	// [task waitUntilExit];
	// int status = [task terminationStatus];
}


@end
