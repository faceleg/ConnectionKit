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


@class KTParsedKeyPath, KTHTMLParser, KTHTMLTextBlock;


@interface KTParsedWebViewComponent : NSObject
{
	id <KTWebViewComponent>	myComponent;
	NSString				*myTemplateHTML;
	NSString				*myDivID;
	NSMutableSet			*myKeyPaths;
	NSMutableSet			*myTextBlocks;
    
    NSString        *myHTML;
	
	NSMutableSet				*mySubcomponents;
	KTParsedWebViewComponent	*mySupercomponent;
	
	BOOL	myNeedsReload;
}

- (id)initWithParser:(KTHTMLParser *)parser;

- (id <KTWebViewComponent>)parsedComponent;
- (NSString *)templateHTML;
- (NSString *)divID;

- (NSString *)HTML;
- (void)setHTML:(NSString *)HTML;

- (NSSet *)parsedKeyPaths;
- (void)addParsedKeyPath:(KTParsedKeyPath *)keypath;
- (void)removeAllParsedKeyPaths;

- (NSSet *)textBlocks;
- (void)addTextBlock:(KTHTMLTextBlock *)textBlock;
- (void)removeAllTextBlocks;

- (NSSet *)subcomponents;
- (NSSet *)allSubcomponents;
- (void)addSubcomponent:(KTParsedWebViewComponent *)component;
- (void)removeAllSubcomponents;

- (KTParsedWebViewComponent *)supercomponent;
- (NSSet *)allSupercomponents;

- (KTParsedWebViewComponent *)componentWithParsedComponent:(id <KTWebViewComponent>)component
											  templateHTML:(NSString *)templateHTML;

- (BOOL)needsReload;
- (void)setNeedsReload:(BOOL)flag;
- (void)setNeedsReload:(BOOL)flag recursive:(BOOL)recursive;

@end
