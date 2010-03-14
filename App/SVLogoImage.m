//
//  SVLogoImage.m
//  Sandvox
//
//  Created by Mike on 02/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLogoImage.h"


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:200] forKey:@"width"];
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:128] forKey:@"height"];
}

- (void)createDefaultIntroAndCaption; { }

@dynamic hidden;

- (NSString *)title { return nil; }
- (void)setTitle:(NSString *)title { }
- (SVRichText *)introduction { return nil; }
- (void)setIntroduction:(SVRichText *)caption { }
- (SVRichText *)caption { return nil; }
- (void)setCaption:(SVRichText *)caption { }

- (SVTextAttachment *)textAttachment { return nil; }

- (BOOL)isPagelet { return NO; }

- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose
{
    NSURL *result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    return result;
}

@end
