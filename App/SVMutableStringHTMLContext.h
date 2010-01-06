//
//  SVMutableStringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  A concrete SVHTMLContext subclass that handles writing by simply appending to a mutable string. Kinda like creating a bitmap graphics context


#import "SVHTMLContext.h"


@interface SVMutableStringHTMLContext : SVHTMLContext
{
  @private
    NSMutableString *_mutableString;
}

- (id)initWithMutableString:(NSMutableString *)string;  // designated initializer
- (id)init; // Uses an empty NSMutableString

@property(nonatomic, retain, readonly) NSMutableString *mutableString;

//  Generally preferable to accessing the mutable string, as it may perform additional processing
- (NSString *)markupString;

@end
