//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 09/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVStringAttribute.h"


@class KTAbstractPage;
@class SVBodyParagraph;


@interface SVLink : SVStringAttribute  
{
}

@property (nonatomic, retain) KTAbstractPage * page;

@end



