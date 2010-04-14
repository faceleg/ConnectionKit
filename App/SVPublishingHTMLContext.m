//
//  SVPublishingHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingHTMLContext.h"

#import "SVMediaRepresentation.h"
#import "KTPage.h"
#import "KTPublishingEngine.h"

#import "NSString+Karelia.h"


@implementation SVPublishingHTMLContext

- (void)dealloc
{
    [_publishingEngine release];
    
    [super dealloc];
}

@synthesize publishingEngine = _publishingEngine;

- (void)close;
{
    [super close];
    
    
    // Generate HTML data
	NSString *HTML = (NSString *)[self stringWriter];
    if (HTML)
    {
        NSStringEncoding encoding = [self encoding];
        NSData *pageData = [HTML dataUsingEncoding:encoding allowLossyConversion:YES];
        OBASSERT(pageData);
        
        
        // Give subclasses a chance to ignore the upload
        KTPublishingEngine *publishingEngine = [self publishingEngine];
        KTPage *page = [self currentPage];
        NSString *fullUploadPath = [[publishingEngine baseRemotePath]
                                    stringByAppendingPathComponent:[page uploadPath]];
        NSData *digest = nil;
        if (![publishingEngine shouldUploadHTML:HTML
                                       encoding:encoding
                                        forPage:page
                                         toPath:fullUploadPath
                                         digest:&digest])
        {
            return;
        }
        
        
        
        // Upload page data. Store the page and its digest with the record for processing later
        if (fullUploadPath)
        {
            CKTransferRecord *transferRecord = [publishingEngine uploadData:pageData
                                                                     toPath:fullUploadPath];
            OBASSERT(transferRecord);
            
            [transferRecord setProperty:page forKey:@"object"];
        }
    }
}

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSNumber *)width
                      height:(NSNumber *)height;
{
    SVMediaRepresentation *rep = [[SVMediaRepresentation alloc] initWithMediaRecord:media
                                                                              width:width
                                                                             height:height
                                                                           fileType:(NSString *)kUTTypePNG];
    
    KTPublishingEngine *pubEngine = [self publishingEngine];
    NSString *path = [pubEngine publishMediaRepresentation:rep];
    [rep release];
    
    NSString *basePath = [pubEngine baseRemotePath];
    if (![basePath hasSuffix:@"/"]) basePath = [basePath stringByAppendingString:@"/"];
    NSString *relPath = [path pathRelativeToPath:basePath];
    
    [self writeImageWithIdName:idName
                     className:className
                           src:relPath
                           alt:altText
                         width:[width description]
                        height:[height description]];
}

@end
