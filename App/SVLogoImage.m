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

- (NSString *)title { return nil; }
- (void)setTitle:(NSString *)title { }

- (SVTextAttachment *)textAttachment { return nil; }

- (void)writeHTML;
{
    [self writeBody];
}

@end
