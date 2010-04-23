// 
//  SVPageBody.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBody.h"

#import "SVGraphic.h"
#import "KTPage.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"


@implementation SVPageBody 

@dynamic page;

- (void)setString:(NSString *)string attachments:(NSSet *)attachments;
{
    [super setString:string attachments:attachments];
    
    
    // Make sure out page's thumbnail source graphic matches up
    KTPage *page = [self page];
    SVGraphic *thumbnailGraphic = [page thumbnailSourceGraphic];
    if (!thumbnailGraphic || ![attachments containsObject:[thumbnailGraphic textAttachment]])
    {
        thumbnailGraphic = [[[self orderedAttachments] firstObjectKS] graphic];
        [page setThumbnailSourceGraphic:thumbnailGraphic];
    }
}

@end
