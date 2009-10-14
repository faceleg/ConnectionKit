//
//  Sandvox.h
//  Sandvox
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

// defines/enums/strings used throughout Sandvox
#import "KT.h"

// Debugging
#import "Debug.h"
#import "assertions.h"
#import "Macros.h"

// Document
#import "KTSite.h"

// Core Data
#import "KTManagedObject.h"

// Plugins (abstract superclass of all plugins)
#import "KTAbstractElement.h"
#import "KTAbstractPluginDelegate.h"

// Page composition
#import "KTAbstractPage.h"
#import "KTPage.h"
#import "KTPagelet.h"
#import "KTMaster.h"

// Template parsing
#import "KTTemplateParser.h"
#import "SVHTMLTemplateParser.h"

//  Media
#import "KTMediaFile.h"
#import "KTMediaFileUpload.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "KTImageScalingSettings.h"

// DataSources (drag-and-drop external sources)
#import "KTDataSourceProtocol.h"

// Indexes
#import "KTAbstractIndex.h"

// Publishing
#import "KTHostProperties.h"

// Foundation/AppKit subclasses
#import "KSEmailAddressComboBox.h"
#import "KSLabel.h"
#import "KSPathInfoField.h"
#import "KSPlaceholderTableView.h"
#import "KSSmallDatePicker.h"
#import "KSTrimFirstLineFormatter.h"
#import "KSVerticallyAlignedTextCell.h"
#import "KSWebLocation.h"

// Foundation extensions
#import "NSAppleScript+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSData+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSIndexPath+Karelia.h"
#import "NSIndexSet+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSet+KTExtensions.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"

// CoreData extensions
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

// AppKit extensions
#import "NSApplication+Karelia.h"
#import "NSArrayController+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSBitmapImageRep+Karelia.h"

// Value Transformers
#import "KSContainsObjectValueTransformer.h"
#import "KSIsEqualValueTransformer.h"

//  Drag-and-Drop
#import "KTLinkSourceView.h"

//  RTFD to HTML conversion
#import "KTRTFDImporter.h"

// Third Party
#import "DNDArrayController.h"
#import "NTBoxView.h"
#import "BDAlias.h"
