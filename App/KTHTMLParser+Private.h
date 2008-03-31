//
//  KTHTMLParser+Private.h
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLParser.h"


@interface KTHTMLParser (Private)

+ (NSDictionary *)parametersDictionaryWithString:(NSString *)parametersString;

- (KTHTMLParserMasterCache *)cache;

- (KTHTMLParser *)newChildParserWithTemplate:(NSString *)templateHTML component:(id <KTWebViewComponent>)component;

- (NSString *)resourceFilePathRelativeToCurrentPage:(NSString *)resourceFile;

// Delegate
- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
- (void)didParseTextBlock:(KTWebViewTextBlock *)textBlock;
- (void)didEncounterResourceFile:(NSString *)resourcePath;

@end
