//
//  OmniCompatibility.h
//  MiniCocoaTech
//
//  Copyright (c) 2004 Terrence J. Talbot. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSObject (OmniCompatibility)
+ (NSBundle *)bundle;
- (NSBundle *)bundle;
@end

@interface NSMutableString (OmniCompatibility)
- (void)appendCharacter:(unichar)aCharacter;
@end
