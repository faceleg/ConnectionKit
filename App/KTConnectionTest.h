//
//  KTConnectionTest.h
//  Marvel
//
//  Created by Mike on 19/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


//  KTConnectionTest takes the user's entered host settings and tests them. It does NOT attempt to
//  modify them in any way. The steps are:
//  
//      1) Create all needed directories
//      2) Upload the test file
//      3) Download test file using site URL
//      4) Delete test file - EVEN IF DOWNLOAD FAILED
//      5) Close connection


#import <Cocoa/Cocoa.h>


@class CKConnection;
@protocol KTConnectionTestDelegate;


@interface KTConnectionTest : NSObject
{
    NSURL                           *_siteURL;
    NSURL                           *_connectionURL;
    id <KTConnectionTestDelegate>   _delegate;
    
    // connection
    CKConnection    *_connection;
    
    // test file
    NSData          *_testFileData;
    NSString        *_testFilePath;
    id <NSObject>   _uploadTestFileOperation;
}

- (id)initWithSiteURL:(NSURL *)siteURL connectionURL:(NSURL *)connectionURL delegate:(id <KTConnectionTestDelegate>)delegate;

- (NSURL *)connectionURL;
- (id <KTConnectionTestDelegate>)delegate;

@end


@protocol KTConnectionTestDelegate
- (void)connectionTestDidFinish:(KTConnectionTest *)connectionTest;
- (void)connectionTest:(KTConnectionTest *)connectionTest didFailWithError:(NSError *)error;
@end