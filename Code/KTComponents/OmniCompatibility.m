//
//  OmniCompatibility.m
//  MiniCocoaTech
//
//  Copyright (c) 2004 Terrence J. Talbot. All rights reserved.
//

#import "OmniCompatibility.h"

@implementation NSObject (OmniCompatibility)

+ (NSBundle *)bundle;
{
    return [NSBundle bundleForClass:self];
}

- (NSBundle *)bundle;
{
    return [isa bundle];
}

@end

@implementation NSMutableString (OmniCompatibility)

- (void)appendCharacter:(unichar)aCharacter;
{
    // There isn't a particularly efficient way to do this using the ObjC interface, so...
    const UniChar unicodeCharacters[1] = { aCharacter };
    
    CFStringAppendCharacters((CFMutableStringRef)self, unicodeCharacters, 1);
}

@end
