//
//  SVElementInfoGatheringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"
#import "KSXMLAttributes.h"


@class SVDOMController;


@interface SVElementInfo : NSObject
{
@private
    NSDictionary            *_attributes;
    NSMutableArray          *_subelements;
    id <SVGraphicContainer> _graphicContainer;
}

@property(nonatomic, copy) NSDictionary *attributes;

@property(nonatomic, copy, readonly) NSArray *subelements;
- (void)addSubelement:(SVElementInfo *)element;

@property(nonatomic, retain) id <SVGraphicContainer> graphicContainer;

@end


#pragma mark -


@interface SVElementInfoGatheringHTMLContext : SVHTMLContext
{
  @private
    NSMutableArray  *_topLevelElements;
    
    NSMutableArray  *_openElementInfos;
}

@property(nonatomic, copy, readonly) NSArray *topLevelElements;
@property(nonatomic, retain, readonly) SVElementInfo *currentElement;

@end
