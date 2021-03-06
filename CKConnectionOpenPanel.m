/*
 Copyright (c) 2006, Olivier Destrebecq <olivier@umich.edu>
 All rights reserved.
 
 
 Redistribution and use in source and binary forms, with or without modification, 
 are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list 
 of conditions and the following disclaimer.
 
 Redistributions in binary form must reproduce the above copyright notice, this 
 list of conditions and the following disclaimer in the documentation and/or other 
 materials provided with the distribution.
 
 Neither the name of Olivier Destrebecq nor the names of its contributors may be used to 
 endorse or promote products derived from this software without specific prior 
 written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
 SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
 BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY 
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */


#import "CKConnectionOpenPanel.h"
#import "CKConnectionProtocol.h"
#import "CKConnectionRegistry.h"

#import "NSArray+Connection.h"

@interface CKConnectionOpenPanel (Private)
- (void)setConnection:(id <CKPublishingConnection>)aConnection;
@end


#pragma mark -


@implementation CKConnectionOpenPanel

- (id)initWithRequest:(NSURLRequest *)request;
{
	NSParameterAssert(request);
    NSParameterAssert([request URL]);
    
    
    if ([super initWithWindowNibName: @"ConnectionOpenPanel"])
	{
		id <CKPublishingConnection> connection = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithRequest:request];
        if (connection)
        {
            [self setConnection:connection];
            
            shouldDisplayOpenButton = YES;
            shouldDisplayOpenCancelButton = YES;
            [self setTimeout:30];
            [self setAllowsMultipleSelection: NO];
            [self setCanChooseFiles: YES];
            [self setCanChooseDirectories: YES];
            
            [self setPrompt: [[NSBundle bundleForClass: [self class]] localizedStringForKey: @"open"
                                                                                      value: @"Open"
                                                                                      table: @"localizable"]];
        }
        else
        {
            [self release];
            self = nil;
        }
	}
	
	return self;
}

- (void) awakeFromNib
{
	[openButton setHidden:!shouldDisplayOpenButton];
    [openCancelButton setHidden:!shouldDisplayOpenCancelButton];
    
    // Sort directories like the Finder
    if ([NSString instancesRespondToSelector:@selector(localizedStandardCompare:)])
    {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"fileName"
                                                                       ascending:YES
                                                                        selector:@selector(localizedStandardCompare:)];
        
        [directoryContents setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        [sortDescriptor release];
    }
    
    //observe the selection from the tree controller
	//
	[directoryContents addObserver: self
						forKeyPath: @"selection"
						   options: NSKeyValueObservingOptionNew
						   context: nil];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [directoryContents removeObserver: self
                           forKeyPath: @"selection"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	//if something is selected, then it should say open, else it should say select
	//
		[self setIsSelectionValid: NO];
  
  if ([[directoryContents selectedObjects] count] == 1)
  {
    if ([[[[directoryContents selectedObjects] objectAtIndex: 0] valueForKey: @"isLeaf"] boolValue])  //file
      [self setIsSelectionValid: [self canChooseFiles]];
    else      //folder
      [self setIsSelectionValid: [self canChooseDirectories]];
    
		if ([self canChooseDirectories])
			[self setPrompt: [[NSBundle bundleForClass: [self class]] localizedStringForKey: @"select"
                                                                                value: @"Select"
                                                                                table: @"localizable"]];
		else
			[self setPrompt: [[NSBundle bundleForClass: [self class]] localizedStringForKey: @"open"
                                                                                value: @"Open"
                                                                                table: @"localizable"]];
  }
  else if ([[directoryContents selectedObjects] count] == 0)
  {
    [self setIsSelectionValid: [self canChooseDirectories]];
    
		if ([self canChooseDirectories])
			[self setPrompt: [[NSBundle bundleForClass: [self class]] localizedStringForKey: @"select"
                                                                                value: @"Select"
                                                                                table: @"localizable"]];
		else
			[self setPrompt: [[NSBundle bundleForClass: [self class]] localizedStringForKey: @"open"
                                                                                value: @"Open"
                                                                                table: @"localizable"]];
    
  }
  else //multiple items
  {
    //this can only happen if the table view was set to allow it, which means that we allow multiple selection
    //simply check that everyitems are selectable
    //
    NSEnumerator *theEnum = [[directoryContents selectedObjects] objectEnumerator];
    NSDictionary *currentItem;
    BOOL wholeSelectionIsValid = YES;
    while ((currentItem = [theEnum nextObject]) && wholeSelectionIsValid)
    {
      if ([[[[directoryContents selectedObjects] objectAtIndex: 0] valueForKey: @"isLeaf"] boolValue])
        wholeSelectionIsValid = [self canChooseFiles];
      else
        wholeSelectionIsValid = [self canChooseDirectories];        
    }
    [self setIsSelectionValid: wholeSelectionIsValid];
  }
}

#pragma mark ----=actions=----
- (IBAction) closePanel: (id) sender
{
  //invalidate the timer in case the user dismiss the panel before the connection happened
  //
	[timer invalidate];
	timer = nil;
  
	[[self connection] setDelegate:nil];
	[self setConnection:nil];
	
	if ([sender tag] && 
		([[directoryContents selectedObjects] count] == 1) && 
		![[[[directoryContents selectedObjects] objectAtIndex: 0] valueForKey: @"isLeaf"] boolValue] &&
		![self canChooseDirectories])
	{
		[[self connection] changeToDirectory: [[[directoryContents selectedObjects] objectAtIndex: 0] valueForKey: @"path"]];
		[[self connection] directoryContents];
	}
	else
	{
		if ([[self window] isSheet])
			[[NSApplication sharedApplication] endSheet:[self window] returnCode: [sender tag]];
		else
			[[NSApplication sharedApplication] stopModalWithCode: [sender tag]];
		
		[self close];
	}
	myKeepRunning = NO;
}

- (IBAction) newFolder: (id) sender
{
	[[NSApplication sharedApplication] runModalForWindow: createFolder];
}

- (IBAction) createNewFolder: (id) sender
{
	[[NSApplication sharedApplication] stopModal];
	[createFolder orderOut: sender];
	
	if ([sender tag] == NSOKButton)
	{
		//check that a folder with the same name does not exiss
		//
		BOOL containsObject = NO;
		
		NSEnumerator *theEnum = [[directoryContents arrangedObjects] objectEnumerator];
		id currentObject = nil;
		
		while ((currentObject = [theEnum nextObject]) && !containsObject)
			containsObject = [[currentObject objectForKey: @"fileName"] isEqualToString: [self newFolderName]];
		
		if (!containsObject)
		{
			NSString *dir = [[[self connection] currentDirectory] stringByAppendingPathComponent:[self newFolderName]];
			[[self connection] createDirectoryAtPath:dir posixPermissions:nil];
		}
		else
		{  
			[[self connection] changeToDirectory: [[[self connection] currentDirectory] stringByAppendingPathComponent: [self newFolderName]]];
			[[self connection] directoryContents];      
		}
		
		[self setIsLoading: YES];
	}
}

- (IBAction) goToFolder: (id) sender
{
	unsigned c = [[parentDirectories arrangedObjects] count];
	NSString *newPath = @"";
	if (c > 0)
	{
        NSArray *currentPathComponents = [[[self connection] currentDirectory] pathComponents];
		newPath = [[currentPathComponents subarrayWithRange: NSMakeRange (0, ([[parentDirectories arrangedObjects] count] - [sender indexOfSelectedItem]))] componentsJoinedByString: @"/"];
	}
	
	if ([newPath isEqualToString: @""])
		newPath = @"/";
  
	[self setIsLoading: YES];
	[[self connection] changeToDirectory: newPath];
	[[self connection] directoryContents];
}

- (IBAction) openFolder: (id) sender
{
	if ([sender count])
		if (![[[sender objectAtIndex: 0] valueForKey: @"isLeaf"] boolValue])
		{
			[self setIsLoading: YES];
			[[self connection] changeToDirectory: [[sender objectAtIndex: 0] valueForKey: @"path"]];
			[[self connection] directoryContents];
		}
}

#pragma mark ----=accessors=----
//=========================================================== 
//  connection 
//=========================================================== 
- (id <CKPublishingConnection>)connection
{
	//NSLog(@"in -connection, returned connection = %@", connection);
	
	return [[_connection retain] autorelease]; 
}

- (void)setConnection:(id <CKPublishingConnection>)aConnection
{
	//NSLog(@"in -setConnection:, old value of connection: %@, changed to: %@", connection, aConnection);
	
	if (aConnection == nil)
	{
		//store last directory
		[lastDirectory autorelease];
		lastDirectory = [[_connection currentDirectory] copy];
	}
	
	if (_connection != aConnection) {
		[_connection setDelegate: nil];
		[_connection forceDisconnect];
		if ([_connection conformsToProtocol:@protocol(CKConnection)]) [(id <CKConnection>)_connection cleanupConnection];
		[_connection release];
		_connection = [aConnection retain];
		[_connection setDelegate: self];
	}
}

//=========================================================== 
//  canChooseDirectories 
//=========================================================== 
- (BOOL)canChooseDirectories
{
	//NSLog(@"in -canChooseDirectories, returned canChooseDirectories = %@", canChooseDirectories ? @"YES": @"NO" );
	
	return canChooseDirectories;
}

- (void)setCanChooseDirectories:(BOOL)flag
{
	//NSLog(@"in -setCanChooseDirectories, old value of canChooseDirectories: %@, changed to: %@", (canChooseDirectories ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	canChooseDirectories = flag;
}

//=========================================================== 
//  canChooseFiles 
//=========================================================== 
- (BOOL)canChooseFiles
{
	//NSLog(@"in -canChooseFiles, returned canChooseFiles = %@", canChooseFiles ? @"YES": @"NO" );
	
	return canChooseFiles;
}

- (void)setCanChooseFiles:(BOOL)flag
{
	//NSLog(@"in -setCanChooseFiles, old value of canChooseFiles: %@, changed to: %@", (canChooseFiles ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	canChooseFiles = flag;
}

//=========================================================== 
//  canCreateDirectories 
//=========================================================== 
- (BOOL)canCreateDirectories
{
	//NSLog(@"in -canCreateDirectories, returned canCreateDirectories = %@", canCreateDirectories ? @"YES": @"NO" );
	
	return canCreateDirectories;
}

- (void)setCanCreateDirectories:(BOOL)flag
{
	//NSLog(@"in -setCanCreateDirectories, old value of canCreateDirectories: %@, changed to: %@", (canCreateDirectories ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	canCreateDirectories = flag;
}

//=========================================================== 
//  shouldDisplayOpenButton 
//=========================================================== 
- (BOOL)shouldDisplayOpenButton
{
	//NSLog(@"in -shouldDisplayOpenButton, returned shouldDisplayOpenButton = %@", shouldDisplayOpenButton ? @"YES": @"NO" );
	
	return shouldDisplayOpenButton;
}

- (void)setShouldDisplayOpenButton:(BOOL)flag
{
	//NSLog(@"in -setShouldDisplayOpenButton, old value of shouldDisplayOpenButton: %@, changed to: %@", (shouldDisplayOpenButton ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	shouldDisplayOpenButton = flag;
}

//=========================================================== 
//  shouldDisplayOpenCancelButton 
//=========================================================== 
- (BOOL)shouldDisplayOpenCancelButton
{
	//NSLog(@"in -shouldDisplayOpenCancelButton, returned shouldDisplayOpenCancelButton = %@", shouldDisplayOpenCancelButton ? @"YES": @"NO" );
	
	return shouldDisplayOpenCancelButton;
}

- (void)setShouldDisplayOpenCancelButton:(BOOL)flag
{
	//NSLog(@"in -setShouldDisplayOpenCancelButton, old value of shouldDisplayOpenCancelButton: %@, changed to: %@", (shouldDisplayOpenCancelButton ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	shouldDisplayOpenCancelButton = flag;
}

//=========================================================== 
//  allowsMultipleSelection 
//=========================================================== 
- (BOOL)allowsMultipleSelection
{
	//NSLog(@"in -allowsMultipleSelection, returned allowsMultipleSelection = %@", allowsMultipleSelection ? @"YES": @"NO" );
	
	return allowsMultipleSelection;
}

- (void)setAllowsMultipleSelection:(BOOL)flag
{
	//NSLog(@"in -setAllowsMultipleSelection, old value of allowsMultipleSelection: %@, changed to: %@", (allowsMultipleSelection ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	allowsMultipleSelection = flag;
}

//=========================================================== 
//  isSelectionValid 
//=========================================================== 
- (BOOL)isSelectionValid
{
	//NSLog(@"in -isSelectionValid, returned isSelectionValid = %@", isSelectionValid ? @"YES": @"NO" );
	
	return isSelectionValid;
}

- (void)setIsSelectionValid:(BOOL)flag
{
	//NSLog(@"in -setIsSelectionValid, old value of isSelectionValid: %@, changed to: %@", (isSelectionValid ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	isSelectionValid = flag;
}

//=========================================================== 
//  isLoading 
//=========================================================== 
- (BOOL)isLoading
{
	//NSLog(@"in -isLoading, returned isLoading = %@", isLoading ? @"YES": @"NO" );
	
	return isLoading;
}

- (void)setIsLoading:(BOOL)flag
{
	//NSLog(@"in -setIsLoading, old value of isLoading: %@, changed to: %@", (isLoading ? @"YES": @"NO"), (flag ? @"YES": @"NO") );
	
	isLoading = flag;
}

//=========================================================== 
//  selectedURLs 
//=========================================================== 
- (NSArray *)URLs
{
	NSArray *selectedFiles = [directoryContents selectedObjects];
	
	if (![selectedFiles count])
		selectedFiles = [NSArray arrayWithObject: [NSDictionary dictionaryWithObject: [[self connection] currentDirectory]
																			  forKey: @"filePath"]];
	
	NSEnumerator *theEnum = [selectedFiles objectEnumerator];
	NSDictionary* currentItem;
	NSMutableArray *returnValue = [NSMutableArray array];
	
	while (currentItem = [theEnum nextObject])
	{ 
		NSString *pathToAdd = [currentItem objectForKey: @"filePath"];
		
		//check that we are past the root directory
		//
        id<CKPublishingConnection> connection = [self connection];
        NSString *rootDirectory = [connection rootDirectory];
		if (([pathToAdd rangeOfString: rootDirectory].location == 0) &&
			(![pathToAdd isEqualToString: rootDirectory]))
			[returnValue addObject: [pathToAdd substringFromIndex: [rootDirectory length] + 1]];
		else if ([pathToAdd isEqualToString: rootDirectory])
			[returnValue addObject: @""];
		else  //we have up back to before the root directory path needs ../ added
		{
			NSString *pathPrefix = @"";
			while ([pathToAdd rangeOfString: rootDirectory].location == NSNotFound)
			{
				pathPrefix = [pathPrefix stringByAppendingPathComponent: @"../"];
				rootDirectory = [rootDirectory stringByDeletingLastPathComponent];
			}
			pathToAdd = [pathPrefix stringByAppendingPathComponent: pathToAdd];
			
			[returnValue addObject:[NSURL URLWithString:pathToAdd relativeToURL:[[connection request] URL]]];
		}
	}
	
	return [[returnValue copy] autorelease]; 
}

//=========================================================== 
//  fileNames 
//=========================================================== 
- (NSArray *)filenames
{
	NSArray *selectedFiles = [directoryContents selectedObjects];
	
	if ([selectedFiles count] == 0)
	{
		if (!lastDirectory) lastDirectory = [[NSString alloc] initWithString:@""];
		selectedFiles = [NSArray arrayWithObject: [NSDictionary dictionaryWithObject: lastDirectory
																			  forKey: @"path"]];
	}
		
	NSEnumerator *theEnum = [selectedFiles objectEnumerator];
	NSDictionary* currentItem;
	NSMutableArray *returnValue = [NSMutableArray array];
	
	while (currentItem = [theEnum nextObject])
	{
        id<CKPublishingConnection> connection = [self connection];
        NSString *rootDirectory = [connection rootDirectory];
        
		if (rootDirectory &&
			[[currentItem objectForKey: @"path"] rangeOfString: rootDirectory].location == 0 &&
			![[currentItem objectForKey: @"path"] isEqualToString: [currentItem objectForKey: @"path"]])
		{
			[returnValue addObject: [[currentItem objectForKey: @"path"] substringFromIndex: [rootDirectory length] + 1]];
		}
		else
		{
			[returnValue addObject: [currentItem objectForKey: @"path"]];  
		}
	}
	
	return [[returnValue copy] autorelease]; 
}

//=========================================================== 
//  prompt 
//=========================================================== 
- (NSString *)prompt
{
	//NSLog(@"in -prompt, returned prompt = %@", prompt);
	
	return [[prompt retain] autorelease]; 
}

- (void)setPrompt:(NSString *)aPrompt
{
	//NSLog(@"in -setPrompt:, old value of prompt: %@, changed to: %@", prompt, aPrompt);
	
	if (prompt != aPrompt) {
		[prompt release];
		prompt = [aPrompt retain];
	}
}

//=========================================================== 
//  allowedFileTypes 
//=========================================================== 
- (NSMutableArray *)allowedFileTypes
{
	//NSLog(@"in -allowedFileTypes, returned allowedFileTypes = %@", allowedFileTypes);
	
	return [[allowedFileTypes retain] autorelease]; 
}

- (void)setAllowedFileTypes:(NSMutableArray *)anAllowedFileTypes
{
	//NSLog(@"in -setAllowedFileTypes:, old value of allowedFileTypes: %@, changed to: %@", allowedFileTypes, anAllowedFileTypes);
	
	if (allowedFileTypes != anAllowedFileTypes) {
		[allowedFileTypes release];
		allowedFileTypes = [anAllowedFileTypes retain];
	}
}


//=========================================================== 
//  initialDirectory 
//=========================================================== 
- (NSString *)initialDirectory
{
	//NSLog(@"in -initialDirectory, returned initialDirectory = %@", initialDirectory);
	
	return [[initialDirectory retain] autorelease]; 
}

- (void)setInitialDirectory:(NSString *)anInitialDirectory
{
	//NSLog(@"in -setInitialDirectory:, old value of initialDirectory: %@, changed to: %@", initialDirectory, anInitialDirectory);
	
	if (initialDirectory != anInitialDirectory) {
		[initialDirectory release];
		initialDirectory = [anInitialDirectory retain];
	}
}

//=========================================================== 
//  newFolderName 
//=========================================================== 
- (NSString *)newFolderName
{
	//NSLog(@"in -newFolderName, returned newFolderName = %@", newFolderName);
	
	return [[newFolderName retain] autorelease]; 
}

- (void)setNewFolderName:(NSString *)aNewFolderName
{
	//NSLog(@"in -setNewFolderName:, old value of newFolderName: %@, changed to: %@", newFolderName, aNewFolderName);
	
	if (newFolderName != aNewFolderName) {
		[newFolderName release];
		newFolderName = [aNewFolderName retain];
	}
}

//=========================================================== 
//  delegate 
//=========================================================== 
- (id)delegate
{
	//NSLog(@"in -delegate, returned delegate = %@", delegate);
	
	return [[_delegate retain] autorelease]; 
}

- (void)setDelegate:(id)aDelegate
{
	//NSLog(@"in -setDelegate:, old value of delegate: %@, changed to: %@", delegate, aDelegate);
	
	if (_delegate != aDelegate) {
		_delegate = aDelegate;
	}
}

//=========================================================== 
//  delegateSelector 
//=========================================================== 
- (SEL)delegateSelector
{
	//NSLog(@"in -delegateSelector, returned delegateSelector = (null)", delegateSelector);
	
	return delegateSelector;
}

- (void)setDelegateSelector:(SEL)aDelegateSelector
{
	//NSLog(@"in -setDelegateSelector, old value of delegateSelector: (null), changed to: (null)", delegateSelector, aDelegateSelector);
	
	delegateSelector = aDelegateSelector;
}

- (void)setTimeout:(NSTimeInterval)to
{
	timeout = to;
}

- (NSTimeInterval)timeout
{
	return timeout;
}

- (void)timedOut:(NSTimer *)timer
{
	[self closePanel: nil];
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void)dealloc
{
	[timer invalidate];
	timer = nil;
	[tableView setDelegate: nil];
	[self setDelegate:nil];
	[self setNewFolderName:nil];
	[self setInitialDirectory:nil];
	[self setPrompt:nil];
	[self setAllowedFileTypes:nil];
	[self setConnection:nil];
	[lastDirectory release];
	
	[super dealloc];
}

#pragma mark ----=running the dialog=----
- (void)beginSheetForDirectory:(NSString *)path file:(NSString *)name modalForWindow:(NSWindow *)docWindow modalDelegate:(id)modalDelegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo
{
  //force the window to be loaded, to be sure tableView is set
  //
  [self window];
  
	[directoryContents setAvoidsEmptySelection: ![self canChooseDirectories]];
	[tableView setAllowsMultipleSelection: [self allowsMultipleSelection]];
	
	[self setDelegate: modalDelegate];
	[self setDelegateSelector: didEndSelector];
	[self retain];
	
	[[NSApplication sharedApplication] beginSheet: [self window]
                                 modalForWindow: docWindow
                                  modalDelegate: self
                                 didEndSelector: @selector(directorySheetDidEnd:returnCode:contextInfo:)
                                    contextInfo: contextInfo];
	[self setInitialDirectory: path];
	
	[self setIsLoading: YES];
	timer = [NSTimer scheduledTimerWithTimeInterval:timeout
											 target:self
										   selector:@selector(timedOut:)
										   userInfo:nil
											repeats:NO];
	[[self connection] connect];
}

- (NSInteger)runModalForDirectory:(NSString *)directory file:(NSString *)filename types:(NSArray *)fileTypes
{
  //force the window to be loaded, to be sure tableView is set
  //
  [self window];
  
	[directoryContents setAvoidsEmptySelection: ![self canChooseDirectories]];
	[tableView setAllowsMultipleSelection: [self allowsMultipleSelection]];
	
	//int ret = [[NSApplication sharedApplication] runModalForWindow: [self window]];
	
	myKeepRunning = YES;
	myModalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[self window]];
	
	[self setInitialDirectory: directory];
	
	[self setIsLoading: YES];
	timer = [NSTimer scheduledTimerWithTimeInterval:timeout
											 target:self
										   selector:@selector(timedOut:)
										   userInfo:nil
											repeats:NO];
	[[self connection] connect];
	
	NSInteger ret;
	for (;;) {
		if (!myKeepRunning)
		{
			break;
		}
		ret = [NSApp runModalSession:myModalSession];
		CFRunLoopRunInMode(kCFRunLoopDefaultMode,1,TRUE);
	}
	
	[NSApp endModalSession:myModalSession];
	
	return ret;
}

- (void) directorySheetDidEnd:(NSWindow*) inSheet returnCode: (NSInteger)returnCode contextInfo:(void*) contextInfo
{
	if ([[self delegate] respondsToSelector: [self delegateSelector]])
	{    
		NSInvocation *callBackInvocation = [NSInvocation invocationWithMethodSignature: [[self delegate] methodSignatureForSelector: [self delegateSelector]]];
		
		[callBackInvocation setTarget: [self delegate]];
		[callBackInvocation setArgument: &self 
								atIndex: 2];
		[callBackInvocation setArgument: &returnCode 
								atIndex: 3];
		[callBackInvocation setArgument: &contextInfo 
								atIndex: 4];
		[callBackInvocation setSelector: [self delegateSelector]];
		
		[callBackInvocation retainArguments];
		[callBackInvocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
	}
	[self autorelease];
}

#pragma mark ----=connection callback=----
- (BOOL)connection:(id <CKConnection>)con authorizeConnectionToHost:(NSString *)host message:(NSString *)message;
{
	[timer invalidate];
	timer = nil;
	if (NSRunAlertPanel(@"Authorize Connection?", @"%@", @"Yes", @"No", nil, message) == NSOKButton)
		return YES;
	return NO;
}

- (void)connection:(id <CKPublishingConnection>)aConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	// Hopefully we can pass off responsibility to the delegate
    id delegate = [self delegate];
    if (delegate && [delegate respondsToSelector:@selector(connectionOpenPanel:didReceiveAuthenticationChallenge:)])
    {
        [delegate connectionOpenPanel:self didReceiveAuthenticationChallenge:challenge];
    }
    else
    {
        // Fallback to the default credentials if possible
        NSURLCredential *credential = [challenge proposedCredential];
        if (credential && [credential user] && [credential hasPassword] && [challenge previousFailureCount] == 0)
        {
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }
        else
        {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }
}

- (void)connection:(id<CKPublishingConnection>)aConn didConnectToHost:(NSString *)host error:(NSError *)error
{
	[timer invalidate];
	timer = nil;
	NSString *dir = [self initialDirectory];
	if (dir && [dir length] > 0) 
		[aConn changeToDirectory: dir];
	[aConn directoryContents];
}

- (void)connection:(id<CKPublishingConnection>)aConn didDisconnectFromHost:(NSString *)host
{
	NSLog (@"disconnect");
}

- (void)connection:(id<CKPublishingConnection>)aConn didReceiveError:(NSError *)error
{
	if ([_delegate respondsToSelector:@selector(connectionOpenPanel:didReceiveError:)])
	{
		[_delegate connectionOpenPanel:self didReceiveError:error];
	}
	else
	{
		
		NSString *informativeText = [error localizedDescription];
		
		NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:informativeText];
        [a setInformativeText:LocalizedStringInConnectionKitBundle(@"Please check your settings.", @"ConnectionOpenPanel")];
        
		[a runModal];
        [a release];
	}
	
	if ([[self window] isSheet])
		[[NSApplication sharedApplication] endSheet:[self window] returnCode: [error code]];
	else
		[[NSApplication sharedApplication] stopModalWithCode: [error code]];
	
	[self closePanel: nil];
}

- (void)connection:(id<CKPublishingConnection>)aConn didCreateDirectory:(NSString *)dirPath error:(NSError *)error
{
	[aConn changeToDirectory:dirPath];
	createdDirectory = [[dirPath lastPathComponent] retain]; 
	[aConn directoryContents];
}

- (void)connection:(id<CKPublishingConnection>)aConn didSetPermissionsForFile:(NSString *)path error:(NSError *)error
{
	
}

- (void)connection:(id<CKPublishingConnection>)aConn didReceiveContents:(NSArray *)contents ofDirectory:(NSString *)dirPath error:(NSError *)error
{
    // An error is most likely the folder not existing, so try loading up the home directory
    if (!contents && error && [dirPath length] > 0)
    {
        [aConn changeToDirectory:@""];
        [aConn directoryContents];
        return;
    }
    
    
    // Populate the popup button used for navigating back to ancestor directories.
    NSArray *pathComponents = [dirPath pathComponents];
    if ([pathComponents count] > 1 &&
        [[pathComponents lastObject] isAbsolutePath])   // ignore trailing slash (-isAbsolutePath avoids hardcoding it)
	{
        pathComponents = [pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 1)];
    }
    
    [parentDirectories setContent:[[pathComponents reverseObjectEnumerator] allObjects]];   // reverse order to match NSSavePanel etc.
	[parentDirectories setSelectionIndex:0];
    
	
    // Populate the file list
    [directoryContents setContent:nil];
	
	for (NSDictionary *cur in [contents filteredArrayByRemovingHiddenFiles])
	{
        NSMutableDictionary *currentItem = [NSMutableDictionary dictionary];
        [currentItem setObject:cur forKey:@"allProperties"];
        [currentItem setObject:[NSMutableArray array] forKey:@"subItems"];
        
        NSString *filename = [cur objectForKey:cxFilenameKey];
        [currentItem setObject:filename forKey:@"fileName"];
        
        BOOL isSymlink = [[cur objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink];
        if (isSymlink)
        {
            NSLog(@"%@: %@", NSStringFromSelector(_cmd), [cur objectForKey:cxSymbolicLinkTargetKey]);
        }
        
        BOOL isDirectory = [[cur objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory];
        
        BOOL isLeaf = (!isDirectory || (isSymlink && ![[cur objectForKey:cxSymbolicLinkTargetKey] hasSuffix:@"/"]));
        [currentItem setObject:[NSNumber numberWithBool:isLeaf] forKey:@"isLeaf"];
        
        [currentItem setObject:[dirPath stringByAppendingPathComponent:filename] forKey:@"path"];
        
        BOOL enabled = (isDirectory ? [self canChooseDirectories] : [self canChooseFiles]);
        [currentItem setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
        
        //get the icon
        NSImage *icon;
        if (isDirectory)
        {
            static NSImage *folder;
            if (!folder)
            {
                folder = [[[NSWorkspace sharedWorkspace] iconForFile:@"/tmp"] copy];
                [folder setSize:NSMakeSize(16,16)];
            }
            
            icon = folder;
        }
        else if (isSymlink)
        {
            static NSImage *symFolder;
            if (!symFolder)
            {
                NSBundle *bundle = [NSBundle bundleForClass:[CKConnectionOpenPanel class]]; // hardcode class incase app subclasses
                symFolder = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"symlink_folder" ofType:@"tif"]];
                [symFolder setSize:NSMakeSize(16,16)];
            }
            static NSImage *symFile;
            if (!symFile)
            {
                NSBundle *bundle = [NSBundle bundleForClass:[CKConnectionOpenPanel class]]; // hardcode class incase app subclasses
                symFile = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"symlink_file" ofType:@"tif"]];
                [symFile setSize:NSMakeSize(16,16)];
            }
            
            NSString *target = [cur objectForKey:cxSymbolicLinkTargetKey];
            if ([target hasSuffix:@"/"] || [target hasSuffix:@"\\"])
            {
                icon = symFolder;
            }
            else
            {
                NSImage *fileType = [[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]];
                NSImage *comp = [[NSImage alloc] initWithSize:NSMakeSize(16,16)];
                [comp lockFocus];
                [fileType drawInRect:NSMakeRect(0,0,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
                [symFile drawInRect:NSMakeRect(0,0,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
                [comp unlockFocus];
                [comp autorelease];
                icon = comp;
            }
        }
        else
        {
            NSString *extension = [filename pathExtension];
            icon = [[[[NSWorkspace sharedWorkspace] iconForFileType:extension] copy] autorelease];  // copy so can mutate
            [icon setSize:NSMakeSize(16,16)];
        }
        
        if (icon) [currentItem setObject:icon forKey:@"image"];
        
        
        // Select the directory that was just created (if there is one)
        if ([filename isEqualToString:createdDirectory]) [directoryContents setSelectsInsertedObjects:YES];
        
        // Actually insert the listed item
        [directoryContents addObject:currentItem];
        [directoryContents setSelectsInsertedObjects:NO];
	}
    
    
    // Want the list sorted like the Finder does
    [directoryContents rearrangeObjects];
	
	[self setIsLoading: NO];
}

/*	Forward on to our delegate if supported
 */
- (void)connection:(id <CKPublishingConnection>)aConnection appendString:(NSString *)string toTranscript:(CKTranscriptType)transcript;
{
	if ([[self delegate] respondsToSelector:@selector(connectionOpenPanel:appendString:toTranscript:)])
	{
		[[self delegate] connectionOpenPanel:self appendString:string toTranscript:transcript];
	}
}

#pragma mark ----=NStableView delegate=----
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	BOOL returnValue = YES;
	
	if ([[[[directoryContents arrangedObjects] objectAtIndex: rowIndex] valueForKey: @"isLeaf"] boolValue])
	{
		returnValue = [self canChooseFiles];
	}
	else
		returnValue = [self canChooseDirectories];
	
	return returnValue;
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	//disable the cell we can't select
	//
	
	BOOL enabled = YES;
	
	if ([[[[directoryContents arrangedObjects] objectAtIndex: rowIndex] valueForKey: @"isLeaf"] boolValue])
	{
		enabled = [self canChooseFiles];
	}
	else
	{
		enabled = [self canChooseDirectories];
	}
		
	
	[aCell setEnabled: enabled];
	if ([aCell isKindOfClass:[NSTextFieldCell class]])
	{
		NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
		if (enabled)
		{
			[attribs setObject:[NSColor textColor] forKey:NSForegroundColorAttributeName];
		}
		else
		{
			[attribs setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
		}
		NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithAttributedString:[aCell attributedStringValue]];
		[str addAttributes:attribs range:NSMakeRange(0,[str length])];
		[aCell setAttributedStringValue:str];
		[str release];
	}
}

@end


