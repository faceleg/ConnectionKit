//
//  KTHTMLParser.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
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

#import <Foundation/Foundation.h>

#import "KTDocument.h"
#import "KTWebViewComponent.h"


@class KTDocument, KTHTMLParserMasterCache, KTMediaFileUpload, KTWebViewTextBlock;
@class KTAbstractPage;
@class KTAbstractMediaFile;

@interface KTHTMLParser : NSObject
{
	NSString				*myID;
	NSString				*myTemplate;
	id <KTWebViewComponent>	myComponent;
	KTHTMLParserMasterCache	*myCache;
	id						myDelegate;
	KTAbstractPage			*myCurrentPage;
	KTHTMLGenerationPurpose	myHTMLGenerationPurpose;
	NSNumber				*myLiveDataFeeds;
	BOOL					myUseAbsoluteMediaPaths;
	KTHTMLParser			*myParentParser;	// Weak ref
	
	NSMutableDictionary	*myOverriddenKeys;
	
	int myIfCount;
	
	NSIndexPath	*myForEachIndexes;
	NSIndexPath *myForEachCounts;
	
	KTDocument *myDocument;
}

+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate component:(id)component;

+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate
						   component:(id <KTWebViewComponent>)component
			   useAbsoluteMediaPaths:(BOOL)useAbsoluteMediaPaths;

- (id)initWithTemplate:(NSString *)HTMLTemplate component:(id <KTWebViewComponent>)parsedComponent;
- (id)initWithPage:(KTAbstractPage *)page;	// Convenience method that parses the whole page

// Accessors
- (NSString *)parserID;
- (NSString *)templateHTML;
- (id <KTWebViewComponent>)component;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (KTAbstractPage *)currentPage;
- (void)setCurrentPage:(KTAbstractPage *)page;

- (KTHTMLGenerationPurpose)HTMLGenerationPurpose;
- (void)setHTMLGenerationPurpose:(KTHTMLGenerationPurpose)purpose;

- (BOOL)liveDataFeeds;
- (void)setLiveDataFeeds:(BOOL)flag;

- (BOOL)useAbsoluteMediaPaths;
- (void)setUseAbsoluteMediaPaths:(BOOL)flag;

- (KTHTMLParser *)parentParser;

// KVC Overrides
- (NSSet *)overriddenKeys;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

// parsing
- (NSString *)parseTemplate;

// Fucntions
- (NSString *)pathToPage:(KTAbstractPage *)page;

@end


@interface KTHTMLParser (Text)
- (KTWebViewTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink;
@end


@interface NSObject (KTHTMLParserDelegate)
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSString *)resourcePath;
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTAbstractMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTWebViewTextBlock *)textBlock;
@end
