//
//  SVPublishingHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingHTMLContext.h"

#import "KTHostProperties.h"
#import "SVMediaRepresentation.h"
#import "KTPage.h"
#import "SVPublisher.h"
#import "KTSite.h"

#import "NSData+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


@implementation SVPublishingHTMLContext

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;
{    
    self = [self init];
    
    _path = [path copy];
    _publisher = [publisher retain];
    
    return self;
}

- (void)close;
{
    // Generate HTML data
    NSString *html = [self mutableString];
	if (html)
    {
        NSStringEncoding encoding = [self encoding];
        NSData *pageData = [html dataUsingEncoding:encoding allowLossyConversion:YES];
        OBASSERT(pageData);
        
        
        // Give subclasses a chance to ignore the upload
        id <SVPublisher> publishingEngine = _publisher;
        KTPage *page = [self page];
        NSString *fullUploadPath = [[publishingEngine baseRemotePath]
                                    stringByAppendingPathComponent:_path];
        
        
        // Generate data digest. It has to ignore the app version string
        NSString *versionString = [NSString stringWithFormat:@"<meta name=\"generator\" content=\"%@\" />",
                                   [[page site] appNameVersion]];
        NSString *versionFreeHTML = [html stringByReplacing:versionString with:@"<meta name=\"generator\" content=\"Sandvox\" />"];
        NSData *digest = [[versionFreeHTML dataUsingEncoding:encoding allowLossyConversion:YES] SHA1Digest];
        
        
        
        // Upload page data. Store the page and its digest with the record for processing later
        if (fullUploadPath)
        {
            [publishingEngine publishData:pageData toPath:fullUploadPath contentHash:digest];
            //OBASSERT(transferRecord);
            //if (page) [transferRecord setProperty:page forKey:@"object"];
        }
    }
    
    
    // Tidy up
    [super close];
    //[_publishingEngine release]; _publishingEngine = nil;     Messes up media gathering
    [_path release]; _path = nil;
}

- (NSURL *)addMedia:(id <SVMedia>)media
              width:(NSNumber *)width
             height:(NSNumber *)height
           type:(NSString *)type;
{
    // When scaling an image, need full suite of parameters
    if (width || height)
    {
        OBPRECONDITION(width);
        OBPRECONDITION(height);
        OBPRECONDITION(type);
    }
    
    
    // If the width and height match the original size, then keep that way
    SVMediaRecord *record = (SVMediaRecord *)media;
    
    if (CGSizeEqualToSize([record originalSize],
                          CGSizeMake([width floatValue], [height floatValue])))
    {
        width = nil;
        height = nil;
    }
    
    SVMediaRepresentation *rep = [[SVMediaRepresentation alloc]
                                  initWithMediaRecord:record
                                  width:width
                                  height:height
                                  type:type];
    
    NSString *path = [_publisher publishMediaRepresentation:rep];
    [rep release];
    
    NSString *basePath = [_publisher baseRemotePath];
    if (![basePath hasSuffix:@"/"]) basePath = [basePath stringByAppendingString:@"/"];
    NSString *relPath = [path pathRelativeToPath:basePath];
    
    if (relPath)
    {
        NSURL *result = [NSURL URLWithString:relPath relativeToURL:[self baseURL]];
        return result;
    }
    
    return nil;
}

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    [super addResourceWithURL:resourceURL];
    [_publisher publishResourceAtURL:resourceURL];
    
    return [[[[self page] site] hostProperties] URLForResourceFile:[resourceURL lastPathComponent]];
}

- (void)addCSSString:(NSString *)css;
{
    [super addCSSString:css];   // should have no effect
    
    // Append to main.css
    [_publisher addCSSString:css];
}

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    [super addCSSWithURL:cssURL];   // should have no effect
    
    // Append to main.css
    [_publisher addCSSWithURL:cssURL];
}

#pragma mark Page

- (void)setPage:(KTPage *)page;
{
    [super setPage:page];
    [self setBaseURL:[page URL]];
}

@end
