//
//  IMStatusImageURLProtocol.m
//  IMStatusElement
//
//  Created by Mike on 03/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "IMStatusImageURLProtocol.h"

#import "Sandvox.h"
#import "NSImage+Karelia.h"


@implementation IMStatusImageURLProtocol

+ (void)load;
{
    [NSURLProtocol registerClass:[IMStatusImageURLProtocol class]];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
{
    NSURL *url = [request URL];
    BOOL result = [[url scheme] isEqualToString:@"x-imstatusimage"];
    return result;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
{
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b;
{
    return [a isEqual:b];
}

- (void)startLoading;
{
    NSURL *requestURL = [[self request] URL];
    NSDictionary *query = [requestURL svQueryParameters];
    
    NSString *headline = [query objectForKey:@"headline"];
    NSString *status = [query objectForKey:@"status"];
    
    NSURL *url = [[[NSURL alloc] initWithScheme:@"file"
                                           host:[requestURL host]
                                           path:[requestURL path]] autorelease];
    
    NSImage *baseImage = [[NSImage alloc] initWithContentsOfURL:url];
    [baseImage normalizeSize];
    
    NSImage *image = [[self class] imageWithBaseImage:baseImage
                                             headline:headline
                                               status:status];
    [baseImage release];
    
    NSData *pngRepresentation = [[image bitmap]
                                 representationUsingType:NSPNGFileType
                                 properties:[NSDictionary dictionary]];
    
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:requestURL
                                                        MIMEType:(NSString *)kUTTypePNG
                                           expectedContentLength:[pngRepresentation length]
                                                textEncodingName:nil];
    [[self client] URLProtocol:self
            didReceiveResponse:response
            cacheStoragePolicy:NSURLCacheStorageAllowed];
    [response release];
    
    [[self client] URLProtocol:self didLoadData:pngRepresentation];
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void)stopLoading; { }

+ (NSImage *)imageWithBaseImage:(NSImage *)aBaseImage headline:(NSString *)aHeadline status:(NSString *)aStatus
{
	NSFont* font1 = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
	NSFont* font2 = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
	NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowOffset:NSMakeSize(0.5, -2.0)];
	[aShadow setShadowBlurRadius:2.0];
	[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	
	NSMutableDictionary *attributes1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        font1, NSFontAttributeName, 
                                        aShadow, NSShadowAttributeName, 
                                        [NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
                                        nil];
    
	NSMutableDictionary *attributes2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        font2, NSFontAttributeName, 
                                        aShadow, NSShadowAttributeName, 
                                        [NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
                                        nil];
	
	NSSize textSize1 = [aHeadline sizeWithAttributes:attributes1];
	if (textSize1.width > 100)
	{
		attributes1 = attributes2;	// use the smaller size if it's going to be too large to fit well, but otherwise overflow...
	}
    
	NSImage *result = [[[NSImage alloc] initWithSize:[aBaseImage size]] autorelease];
	[result lockFocus];
	[aBaseImage drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0,0,[aBaseImage size].width, [aBaseImage size].height) operation:NSCompositeCopy fraction:1.0];
	
	[aHeadline drawAtPoint:NSMakePoint(19,40) withAttributes:attributes1];
	[aStatus drawAtPoint:NSMakePoint(32,12) withAttributes:attributes2];
    
	[result unlockFocus];
	return result;
}

+ (NSURL *)baseOnlineImageURL;
{
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"online"];
    return [NSURL fileURLWithPath:path];
}

+ (NSURL *)baseOfflineImageURL;
{
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"offline"];
    return [NSURL fileURLWithPath:path];
}

+ (NSURL *)URLWithBaseImageURL:(NSURL *)baseURL headline:(NSString *)headline status:(NSString *)status;
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] initWithCapacity:2];
    [query setValue:headline forKey:@"headline"];
    [query setValue:status forKey:@"status"];
    
    NSURL *result = [NSURL svURLWithScheme:@"x-imstatusimage"
                                      host:[baseURL host]
                                      path:[baseURL path]
                           queryParameters:query];
    
    [query release];
    
    return result;
}

@end
