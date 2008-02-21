//
//  Sandvox.h
//  Sandvox
//
//  Copyright (c) 2004-2008, Karelia Software. All rights reserved.
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

// SandvoxPlugin.h is a convenience header that imports all "public" headers in Sandvox
//  should be sufficient for almost all plugins

// Safari 3 WebKit methods, available in 10.4.11 and above
#import "KTWebKitCompatibility.h"

// defines/enums used throughout Sandvox
#import "KT.h"

#import "KTBundleManager.h"
#import "KTDocument.h"

// debugging
#import "Debug.h"
#import "assertions.h"

// Core Data classes
#import "KTManagedObjectContext.h"
#import "KTPersistentStoreCoordinator.h"

//  superclass of all managed objects
#import "KTManagedObject.h"

//  abstract superclass of all plugins (bundles)
#import "KTAbstractPlugin.h"
#import "KTAbstractPluginDelegate.h"

#import "KTAppPlugin.h"
#import "KTAbstractHTMLPlugin.h"
#import "KTIndexPlugin.h"

//  major Core Data-based plugin superclasses
#import "KTPage.h"
#import "KTPagelet.h"

//  media
#import "KTAbstractMediaFile.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"

// abstract superclass of all data sources (drag-and-drop external sources)
#import "KTAbstractDataSource.h"

// abstract superclass of all indexes
#import "KTAbstractIndex.h"

// Foundation/AppKit subclasses
#import "KTEmailAddressComboBox.h"
#import "KTImageView.h"
#import "KTLabel.h"
#import "KTPlaceholderTableView.h"
#import "KTSmallDatePicker.h"
#import "KTSmallDatePickerCell.h"
#import "KTTrimFirstLineFormatter.h"
#import "KTValidateCharFormatter.h"
#import "KTVerticallyAlignedTextCell.h"

// Foundation extensions
#import "NSAppleScript+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSMutableArray+Karelia.h"
#import "NSMutableSet+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBitmapImageRep+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSCalendarDate+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSData+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSMutableDictionary+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSIndexPath+Karelia.h"
#import "NSIndexSet+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"
#import "NSSet+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSScanner+Karelia.h"

// CoreData extensions
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

// CoreImage extensions
#import "CIImage+Karelia.h"

// AppKit extensions
#import "NSApplication+Karelia.h"
#import "NSArrayController+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSWorkspace+Karelia.h"

// WebCore extensions
#import "DOMNode+KTExtensions.h"

// Value Transformers
#import "CharsetToEncodingTransformer.h"
#import "ContainerIsEmptyTransformer.h"
#import "ContainsValueTransformer.h"
#import "ContainerIsNotEmptyTransformer.h"
#import "EscapeHTMLTransformer.h"
#import "RichTextHTMLTransformer.h"
#import "RowHeightTransformer.h"
#import "StripHTMLTransformer.h"
#import "TrimFirstLineTransformer.h"
#import "TrimTransformer.h"
#import "StringToNumberTransformer.h"
#import "ValuesAreEqualTransformer.h"

// general support

//  drag-and-drop
#import "KTDraggingInfo.h"
#import "KTLinkSourceView.h"

//  RTFD to HTML conversion
#import "KTRTFDImporter.h"

//  intelligently dismissable sheet
#import "KTSilencingConfirmSheet.h"


#import "KTPluginInspectorViewsManager.h"
#import "QuickLookSandvoxPlugin.h"



#import "KTWebViewComponent.h"

#import "KTPasteboardArchiving.h"

#import "KTInDocumentMediaFile.h"

#import "DNDArrayController.h"
#import <NTBoxView.h>
#import <KTPathInfoField.h>
#import <KTPathInfoFieldCell.h>
#import <KTDesign.h>
#import <KTMaster.h>
#import <KTMediaContainer.h>
#import <KTAbstractMediaFile.h>
#import <KTPathInfoField.h>
#import <NSMutableSet+Karelia.h>
#import <KTHTMLParser.h>
#import "KTDocWindowController.h"
#import "NSString+KTExtensions.h"

