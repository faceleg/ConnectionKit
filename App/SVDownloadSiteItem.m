//
//  SVDownloadSiteItem.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDownloadSiteItem.h"

#import "SVMediaRecord.h"
#import "KTPage+Paths.h"
#import "SVPublisher.h"

#import "NSData+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVDownloadSiteItem

@dynamic media;
- (void)setMedia:(SVMediaRecord *)media
{
    [self willChangeValueForKey:@"media"];
    [self setPrimitiveValue:media forKey:@"media"];
    [self didChangeValueForKey:@"media"];
    
    [self setTitle:[[media preferredFilename] stringByDeletingPathExtension]];
}

- (SVMediaRecord *)mediaRepresentation;
{
    return [self media];
}
+ (NSSet *)keyPathsForValuesAffectingMediaRepresentation
{
    return [NSSet setWithObject:@"media"];
}

#pragma mark Thumbnail

- (id)imageRepresentation;
{
    id result = [super imageRepresentation];
    if (!result) 
    {
        result = [[NSWorkspace sharedWorkspace] iconForFileType:
                  [[[self media] preferredFilename] pathExtension]];
    }
    return result;
}

- (NSString *) imageRepresentationType
{
    NSString *result = ([super imageRepresentation] ?
                     [super imageRepresentationType] :
                     IKImageBrowserNSImageRepresentationType);
    
    return result;
}

#pragma mark Publishing

- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
{
    SVMedia *media = [[self media] media];
    
    NSString *uploadPath = [publishingEngine baseRemotePath];
    uploadPath = [uploadPath stringByAppendingPathComponent:[[self parentPage] uploadPath]];
    uploadPath = [uploadPath stringByDeletingLastPathComponent];
    uploadPath = [uploadPath stringByAppendingPathComponent:
                  [[media preferredUploadPath] lastPathComponent]];
    
    [publishingEngine publishContentsOfURL:[media mediaURL]
                                    toPath:uploadPath
                          cachedSHA1Digest:nil
                                    object:self];
}

// For display in the placeholder webview
- (NSURL *)URL
{
    NSURL *result = nil;
    
    NSString *filename = [[self filename] legalizedWebPublishingFilename];
    if (filename)
    {
        result = [[NSURL alloc] initWithString:filename
                                 relativeToURL:[[self parentPage] URL]];
    }
    
    return [result autorelease];
}

- (NSString *)filename { return [self.media preferredFilename]; }

@dynamic fileName;
- (void)setFileName:(NSString *)name;
{
    [self willChangeValueForKey:@"fileName"];
    [self setPrimitiveValue:name forKey:@"fileName"];
    
    // This invalidates publishing status
    [self setDatePublished:nil];
    
    [self didChangeValueForKey:@"fileName"];
}

- (KTMaster *)master; { return [[self parentPage] master]; }

#pragma mark KTHTMLSourceObject

- (NSString *)HTMLString;
{
    SVMedia *media = [[self media] media];
    
    WebResource *webResource = [media webResource];
    if (webResource)
    {
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)[webResource textEncodingName]);
        
        return [NSString stringWithData:[webResource data]
                               encoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
    }
    
    return [NSString stringWithContentsOfURL:[media mediaURL]
                            fallbackEncoding:NSUTF8StringEncoding
                                       error:NULL];
}

- (void)setHTMLString:(NSString *)html;
{
    /*
    WebResource *webResource = [[WebResource alloc]
                                initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]
                                URL:[NSURL URLWithString:@"x-sandvox://foogly.boo"]
                                MIMEType:[NSString MIMETypeForUTI:(NSString *)kUTTypePlainText]
                                textEncodingName:<#(NSString *)textEncodingName#> frameName:<#(NSString *)frameName#>]*/
    
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:
                                    @"x-sandvox-fake-url:///%@.html",
                                    [data sha1DigestString]]];
    
    SVMedia *media = [[SVMedia alloc] initWithData:data URL:url];
    [media setPreferredFilename:[self filename]];
    
    SVMediaRecord *record = [SVMediaRecord mediaRecordWithMedia:media
                                                     entityName:@"FileMedia"
                                 insertIntoManagedObjectContext:[self managedObjectContext]];
    
    [self replaceMedia:record forKeyPath:@"media"];
    [media release];
}

- (NSNumber *)docType; { return [self valueForUndefinedKey:@"docType"]; }
- (void) setDocType:(NSNumber *)docType; { [self setValue:docType forUndefinedKey:@"docType"]; }

- (NSData *) lastValidMarkupDigest; { return nil; }
- (void) setLastValidMarkupDigest:(NSData *)digest; { }

- (NSNumber *)shouldPreviewWhenEditing; { return NSBOOL(YES); }
- (void) setShouldPreviewWhenEditing:(NSNumber *)preview; { }

- (BOOL) usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    return ([key isEqualToString:@"docType"] ?
            YES :
            [super usesExtensiblePropertiesForUndefinedKey:key]);
}

@end
