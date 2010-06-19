//
//  SVPublisherStringWriter.h
//  Sandvox
//
//  Created by Mike on 19/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSStringStream.h"


@protocol SVPublisher;


@interface SVPublishDataWriter : NSObject <KSWriter>
{
  @private
    NSMutableString *_string;
    
    id <SVPublisher>    _publisher;
    NSString            *_uploadPath;
    NSStringEncoding    _encoding;
}

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher
                encoding:(NSStringEncoding)encoding;

- (void)close;  // Publishes the written string using the parameters specified at initialization time. Then releases resources

@property(nonatomic, copy, readonly) NSString *uploadPath;
@property(nonatomic, retain, readonly) id <SVPublisher> publisher;
@property(nonatomic, readonly) NSStringEncoding encoding;

@end
