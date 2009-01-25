//
//  KTConnectionTest.m
//  Marvel
//
//  Created by Mike on 19/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTConnectionTest.h"

#import "NSApplication+Karelia.h"
#import "NSString+Karelia.h"

#import <Connection/Connection.h>


@interface KTConnectionTest ()
- (void)uploadTestFile;
@end


#pragma mark -


@implementation KTConnectionTest

- (id)initWithSiteURL:(NSURL *)siteURL connectionURL:(NSURL *)connectionURL delegate:(id <KTConnectionTestDelegate>)delegate
{
    OBPRECONDITION(siteURL);
    OBPRECONDITION([siteURL host]); // TODO: Check host is fully valid
    
    OBPRECONDITION(connectionURL);
    OBPRECONDITION([connectionURL host]);
    
    
    // Init
    [super init];
    
    
    // Store properties
    _siteURL = [siteURL copy];
    _connectionURL = [connectionURL copy];
    _delegate = delegate;
    
    
    // Start the connection
    CKConnectionRequest *request = [[CKConnectionRequest alloc] initWithURL:connectionURL];
    _connection = [[CKConnection alloc] initWithConnectionRequest:request delegate:self];
    [request release];
    
    
    // Create directories
    [_connection createDirectoryAtPath:[_connectionURL path] withIntermediateDirectories:YES identifier:nil];
    
    
    // Upload test file
    [self uploadTestFile];
    
    
    return self;
}

- (void)dealloc
{
    [_siteURL release];
    [_connectionURL release];
    [_connection release];
    
    [super dealloc];
}

#pragma mark Accessors

- (NSURL *)connectionURL { return _connectionURL; }

- (id <KTConnectionTestDelegate>)delegate
{
    return _delegate;
}

#pragma mark Test methods

- (void)uploadTestFile
{
    OBASSERT(!_testFilePath && !_testFileData);
        
    NSString *fileName = [NSString stringWithFormat:@"Temp_%@.html", [NSString shortUUIDString]];	// DO NOT LOCALIZE
    _testFilePath = [[[[self connectionURL] path] stringByAppendingPathComponent:fileName] copy];
    
    // Put a UTF-8 marker (will this help?) into file to ensure it's parse as UTF8.
    // TODO: Actually encode the test file in the encoding specified by the hostproperties/site.
    NSString *fileContents = [NSString stringWithFormat:NSLocalizedString(@"%@ This temporary file can be safely deleted if it is found.\n%@ created this file to verify that this computer was reachable over the Internet.",
                                                                          @"explanation going inside temporary file"),
                              @"// !$*UTF8*$!\n\n",
                              [NSApplication applicationName]];
    
    // wrapping this in html separately so we don't change any localized strings
    NSString *htmlWrapper = [NSString stringWithFormat:@"<html><body><p>%@</p></body></html>", fileContents];
    _testFileData = [[htmlWrapper dataUsingEncoding:NSUTF8StringEncoding] copy];
    
    _uploadTestFileOperation = [[_connection uploadData:_testFileData toPath:_testFilePath identifier:nil] retain];
}

#pragma mark Connection delegate

- (void)connection:(CKConnection *)connection didFailWithError:(NSError *)error
{
    [[self delegate] connectionTest:self didFailWithError:error];
}

- (void)connection:(CKConnection *)connection operationDidFinish:(id)identifier;
{
    
}

- (void)connection:(CKConnection *)connection operation:(id)identifier didFailWithError:(NSError *)error
{
    [[self delegate] connectionTest:self didFailWithError:error];
}

@end
