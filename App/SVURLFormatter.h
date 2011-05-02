//
//  SVURLFormatter.h
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Foundation/Foundation.h>


// Do NOT try to subclass SVURLFormatter as your code will definitely break at some point
@interface SVURLFormatter : NSFormatter
+ (NSURL *)URLFromString:(NSString *)string;    // convenience
- (NSURL *)URLFromString:(NSString *)string;    // convenience
@end