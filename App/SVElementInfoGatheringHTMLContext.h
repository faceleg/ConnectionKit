//
//  SVElementInfoGatheringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"
#import "KSXMLAttributes.h"


@class KSObjectKeyPathPair;


@interface SVElementInfo : NSObject
{
@private
    NSDictionary            *_attributes;
    NSMutableArray          *_subelements;
    
    id <SVGraphicContainer> _graphicContainer;
    NSMutableSet            *_dependencies;
}

- (id)initWithGraphicContainer:(id <SVGraphicContainer>)container;
@property(nonatomic, retain, readonly) id <SVGraphicContainer> graphicContainer;

@property(nonatomic, copy) NSDictionary *attributes;

@property(nonatomic, copy, readonly) NSArray *subelements;
- (void)addSubelement:(SVElementInfo *)element;


- (NSSet *)dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)dependency;

@end


#pragma mark -


@interface SVElementInfoGatheringHTMLContext : SVHTMLContext
{
  @private
    SVElementInfo  *_root;
    
    NSMutableArray  *_openElementInfos;
    SVElementInfo   *_earlyElement;
}

@property(nonatomic, retain, readonly) SVElementInfo *rootElement;
@property(nonatomic, retain, readonly) SVElementInfo *currentElement;

- (void)addDependency:(KSObjectKeyPathPair *)dependency;

@end
