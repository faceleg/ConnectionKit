//
//  KTParsedWebViewComponent.h
//  Marvel
//
//  Created by Mike on 24/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//
//	Represents an object that was parsed with an HTML template to form a portion of a page's HTML.
//	KTDocWebViewController maintains the hierarchy of these objects.


#import <Cocoa/Cocoa.h>

#import "KTWebViewComponent.h"


@class KTParsedKeyPath;


@interface KTParsedWebViewComponent : NSObject
{
	id <KTWebViewComponent>	myComponent;
	NSString				*myTemplateHTML;
	NSString				*myDivID;
	NSMutableSet			*myKeyPaths;
	NSMutableSet			*mySummaryTextBlocks;
	
	NSMutableSet				*mySubComponents;
	KTParsedWebViewComponent	*mySuperComponent;
}

- (id)initWithParser:(KTHTMLParser *)parser;

- (id <KTWebViewComponent>)parsedComponent;
- (NSString *)templateHTML;
- (NSString *)divID;

- (NSSet *)parsedKeyPaths;
- (void)addParsedKeyPath:(KTParsedKeyPath *)keypath;
- (void)removeAllParsedKeyPaths;

- (NSSet *)textBlocks;
- (void)addTextBlock:(KTWebViewTextEditingBlock *)textBlock;
- (void)removeAllTextBlocks;

- (NSSet *)subComponents;
- (NSSet *)allSubComponents;
- (void)addSubComponent:(KTParsedWebViewComponent *)component;
- (void)removeAllSubComponents;

- (KTParsedWebViewComponent *)superComponent;
- (NSSet *)allSuperComponents;

- (KTParsedWebViewComponent *)componentWithParsedComponent:(id <KTWebViewComponent>)component
											  templateHTML:(NSString *)templateHTML;

@end
