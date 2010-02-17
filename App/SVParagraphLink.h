//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 09/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextAttachment.h"


@class KTAbstractPage;
@class SVBodyParagraph;


@interface SVParagraphLink : SVTextAttachment  
{
}

@property (nonatomic, retain) KTAbstractPage * page;

@end



