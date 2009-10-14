//
//  KTHTMLParser+Private.h
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVHTMLTemplateParser.h"


@interface SVHTMLTemplateParser ()

+ (NSDictionary *)parametersDictionaryWithString:(NSString *)parametersString;

- (KTHTMLParserMasterCache *)cache;

- (NSString *)resourceFilePath:(NSURL *)resourceFile relativeToPage:(KTAbstractPage *)page;

// Delegate
- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
- (void)didParseTextBlock:(SVHTMLTemplateTextBlock *)textBlock;
- (void)didEncounterMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;
- (void)didEncounterResourceFile:(NSURL *)resourceURL;

@end
