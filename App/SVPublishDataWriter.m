//
//  SVPublisherStringWriter.m
//  Sandvox
//
//  Created by Mike on 19/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishDataWriter.h"

#import "KTPublishingEngine.h"


@implementation SVPublishDataWriter

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher
                encoding:(NSStringEncoding)encoding;
{
    [self init];
    
    _string = [[NSMutableString alloc] init];
    
    _uploadPath = [path copy];
    _publisher = [publisher retain];
    _encoding = encoding;
    
    return self;
}

- (void)dealloc;
{
    [self close];
    [super dealloc];
}

- (void)writeString:(NSString *)string; { [_string appendString:string]; }

- (void)close;
{
    // Generate HTML data
    NSData *data = [_string dataUsingEncoding:[self encoding] allowLossyConversion:YES];
    OBASSERT(data);
    
    // Publish
    [[self publisher] publishData:data
                           toPath:[self uploadPath]];
    
    // Tidy up
    [_string release]; _string = nil;
    [_uploadPath release]; _uploadPath = nil;
    [_publisher release]; _publisher = nil;
}

@synthesize uploadPath = _uploadPath;
@synthesize publisher = _publisher;
@synthesize encoding = _encoding;

@end
