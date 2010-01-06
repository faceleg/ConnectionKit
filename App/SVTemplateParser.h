//
//  NSTemplateParser.h
//  Sandvox
//
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import "NSString+Karelia.h"


@class KTHTMLParserMasterCache;
@protocol KTTemplateParserDelegate;
@interface SVTemplateParser : NSObject
{
	@private
	
	NSString				*myID;
	NSString				*myTemplate;
	id						myComponent;
	KTHTMLParserMasterCache	*myCache;
	id						myDelegate;
	SVTemplateParser		*myParentParser;	// Weak ref
	
	NSMutableDictionary	*myOverriddenKeys;
	
	NSUInteger  _ifFunctionDepth;
    NSUInteger  _foreachFunctionDepth;
}

- (id)initWithTemplate:(NSString *)templateString component:(id)parsedComponent;

// Accessors
- (NSString *)parserID;
- (NSString *)template;
- (id)component;

@property(nonatomic, assign) id <KTTemplateParserDelegate> delegate;

// KVC Overrides
- (NSSet *)overriddenKeys;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

// Child parsers
- (id)parentParser;
- (id)newChildParserWithTemplate:(NSString *)templateString component:(id)component;

// Parsing
+ (NSString *)parseTemplate:(NSString *)aTemplate component:(id)component;
- (NSString *)parseTemplate;
- (BOOL)prepareToParse;

- (NSString *)componentLocalizedString:(NSString *)tag;
- (NSString *)componentTargetLocalizedString:(NSString *)tag;
- (NSString *)mainBundleLocalizedString:(NSString *)tag;

// If function
- (BOOL)compareIfStatement:(ComparisonType)comparisonType leftValue:(id)leftValue rightValue:(id)rightValue;
- (BOOL)isNotEmpty:(id)aValue;


// Foreach loops
- (NSString *)evaluateForeachLoopWithArray:(NSArray *)components
                           iterationsCount:(NSUInteger)specifiedNumberIterations
                                   keyPath:(NSString *)keyPath
                                    scaner:(NSScanner *)inScanner;
- (NSString *)doForeachIterationWithObject:(id)object
template:(NSString *)stuffToRepeat
keyPath:(NSString *)keyPath;


// Support
@property(nonatomic, retain, readonly) KTHTMLParserMasterCache *cache;
- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
+ (NSDictionary *)parametersDictionaryWithString:(NSString *)parametersString;


@end


@protocol KTTemplateParserDelegate
@optional
- (void)parserDidStartTemplate:(SVTemplateParser *)parser;
- (NSString *)parser:(SVTemplateParser *)parser didEndTemplate:(NSString *)result;
- (void)parser:(SVTemplateParser *)parser willParseSubcomponentAtIndex:(unsigned)index;
@end


@interface NSObject (KTTemplateParserAdditions)
- (NSString *)templateParserStringValue;
@end

