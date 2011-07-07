//
//  SVElementInfoGatheringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"
#import "KSElementInfo.h"


@interface SVElementInfo : KSElementInfo
{
@private
    NSMutableArray  *_subelements;
}

@property(nonatomic, copy, readonly) NSArray *subelements;
- (void)addSubelement:(KSElementInfo *)element;

@end


#pragma mark -


@interface SVElementInfoGatheringHTMLContext : SVHTMLContext
{
  @private
    NSMutableArray  *_openElementInfo;
}

@property(nonatomic, retain, readonly) SVElementInfo *rootElement;
@property(nonatomic, retain, readonly) SVElementInfo *currentElement;


@end
