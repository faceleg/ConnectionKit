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
    
    id <SVComponent> _graphicContainer;
    BOOL                    _elementIdNameWasInvented;
    NSMutableSet            *_dependencies;
    BOOL                    _horizontallyResizable;
    BOOL                    _verticallyResizable;
}

- (id)initWithGraphicComponent:(id <SVComponent>)component;
@property(nonatomic, retain, readonly) id <SVComponent> component;

@property(nonatomic, copy) NSDictionary *attributesAsDictionary;

@property(nonatomic, copy, readonly) NSArray *subelements;
- (void)addSubelement:(SVElementInfo *)element;


#pragma mark Sandvox Properties

@property(nonatomic) BOOL elementIdNameWasInvented;

- (NSSet *)dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)dependency;

@property(nonatomic, getter=isHorizontallyResizable) BOOL horizontallyResizable;
@property(nonatomic, getter=isVerticallyResizable) BOOL verticallyResizable;

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
