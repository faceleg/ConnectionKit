//
//  SVElementInfoGatheringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"
#import "KSXMLAttributes.h"


@interface SVElementInfo : NSObject
{
@private
    NSDictionary    *_attributes;
    NSMutableArray  *_subelements;
    id <SVGraphic>  _graphic;
}

@property(nonatomic, copy) NSDictionary *attributes;

@property(nonatomic, copy, readonly) NSArray *subelements;
- (void)addSubelement:(SVElementInfo *)element;

@property(nonatomic, retain) id <SVGraphic> graphic;

@end


#pragma mark -


@interface SVElementInfoGatheringHTMLContext : SVHTMLContext
{
  @private
    NSMutableArray  *_topLevelElements;
    
    NSMutableArray  *_openElementInfos;
    id <SVGraphic>  _currentGraphic;
}

@property(nonatomic, copy, readonly) NSArray *topLevelElements;
@property(nonatomic, retain, readonly) SVElementInfo *currentElement;


@end
