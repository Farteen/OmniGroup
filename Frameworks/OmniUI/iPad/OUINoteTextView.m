// Copyright 2010-2014 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//

#import <OmniFoundation/NSData-OFEncoding.h>

#import <OmniUI/OUIAppearance.h>
#import <OmniUI/OUINoteTextView.h>

RCS_ID("$Id$");

#define ALLOW_LINK_DETECTION (YES)

CGFloat OUINoteTextViewPlacholderTopMarginAutomatic = -1000;

@interface OUINoteTextView () {
  @private
    BOOL _detectsLinks;
    NSString *_placeholder;
    BOOL _drawsPlaceholder;
    CGFloat _placeholderTopMargin;
    BOOL _drawsBorder;
    BOOL _observingEditingNotifications;
}

@end

#pragma mark -

@implementation OUINoteTextView

- (id)initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }
        
    [self OUINoteTextView_commonInit];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder;
{
    self = [super initWithCoder:coder];
    if (self == nil) {
        return nil;
    }
    
    [self OUINoteTextView_commonInit];
    return self;
}

- (void)OUINoteTextView_commonInit;
{
    _placeholderTopMargin = OUINoteTextViewPlacholderTopMarginAutomatic;
    _drawsPlaceholder = YES;
    _drawsBorder = NO;
    _detectsLinks = ALLOW_LINK_DETECTION;
    
    self.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textColor = [UIColor omniNeutralDeemphasizedColor];
    
    self.contentMode = UIViewContentModeRedraw;
    self.editable = NO;
    self.dataDetectorTypes = UIDataDetectorTypeAll;
    self.alwaysBounceVertical = YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)placeholder;
{
    return _placeholder;
}

- (void)setPlaceholder:(NSString *)placeholder;
{
    if (_placeholder != placeholder) {
        _placeholder = [placeholder copy];
        
        [self _addEditingObserversIfNecessary];

        if ([self _shouldDrawPlaceholder]) {
            [self setNeedsDisplay];
        }
    }
}

- (BOOL)drawsPlaceholder;
{
    return _drawsPlaceholder;
}

- (void)setDrawsPlaceholder:(BOOL)drawsPlaceholder;
{
    _drawsPlaceholder = drawsPlaceholder;
    [self setNeedsDisplay];
}

- (BOOL)drawsBorder;
{
    return _drawsBorder;
}   

- (void)setDrawsBorder:(BOOL)drawsBorder;
{
    if (drawsBorder != _drawsBorder) {
        _drawsBorder = drawsBorder;
        if (_drawsBorder) {
            self.layer.borderColor = [[UIColor lightGrayColor] CGColor];
            self.layer.borderWidth = 1.0;
            self.layer.cornerRadius = 10;
            self.opaque = NO;
        } else {
            self.layer.borderWidth = 0;
            self.layer.cornerRadius = 0;
            self.opaque = YES;
        }
    }

//#ifdef DEBUG_correia
//    self.layer.borderColor = [[UIColor redColor] CGColor];
//    self.layer.borderWidth = 1.0;
//#endif
}

- (void)drawRect:(CGRect)clipRect;
{
    [super drawRect:clipRect];
    
    if ([self _shouldDrawPlaceholder]) {
        UIFont *placeholderFont = [UIFont systemFontOfSize:[UIFont labelFontSize]];
        NSString *placeholder = self.placeholder;
        NSDictionary *attributes = @{
            NSFontAttributeName: placeholderFont,
            NSForegroundColorAttributeName: [UIColor omniNeutralPlaceholderColor],
        };

        CGSize size = self.bounds.size;
        CGRect boundingRect = [placeholder boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil];
        CGRect textRect = self.bounds;
        textRect = UIEdgeInsetsInsetRect(textRect, self.contentInset);
        textRect = UIEdgeInsetsInsetRect(textRect, self.textContainerInset);

        // Draw the placeholder if we have a comformtable amount of vertical space
        if (CGRectGetHeight(textRect) >= 88) {
            textRect.origin.x += (CGRectGetWidth(textRect) - CGRectGetWidth(boundingRect)) / 2.0;
            textRect.origin.y += -1 * self.contentOffset.y - self.contentInset.top;

            if (_placeholderTopMargin != OUINoteTextViewPlacholderTopMarginAutomatic) {
                textRect.origin.y = _placeholderTopMargin;
            } else {
                // If we are regular, but have a reasonably short height, also take the compact code path
                BOOL isVerticallyCompact = (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact);
                if (!isVerticallyCompact && CGRectGetHeight(self.bounds) <= 568) {
                    isVerticallyCompact = YES;
                }
                
                if (isVerticallyCompact) {
                    textRect.origin.y = CGRectGetHeight(textRect) / 3.0 - CGRectGetHeight(boundingRect) / 2.0;
                } else {
                    textRect.origin.y = CGRectGetHeight(textRect) / 2.0 - CGRectGetHeight(boundingRect) / 2.0;
                }
            }

            textRect.size = boundingRect.size;
            textRect = CGRectIntegral(textRect);

            [placeholder drawInRect:textRect withAttributes:attributes];
        }
    }
}

#pragma mark UITextView subclass

- (void)scrollRangeToVisible:(NSRange)range;
{
    // I've re-implemented -scrollRangeToVisible: because UITextView's implementation doesn't work when typing in a text view with a bottom content inset in the item editor in OmniFocus.
    //
    // rdar://problem/14397663
    
    // Need to ensure layout for the entire range or we get the wrong behavior in the edge case of typing at the end of the text.
    NSLayoutManager *layoutManager = self.layoutManager;
    [layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, NSMaxRange(range))];
    
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
    CGRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];

    // Make sure the rect is non-empty.
    // Give us a little vertical breathing room, but don't extend the rect into negative y coordinate space.
    rect = CGRectInset(rect, 0, -1 * self.font.lineHeight);
    rect.origin.y = MAX(0, rect.origin.y);
    rect.size.width = MAX(1, CGRectGetWidth(rect));
    rect = CGRectIntegral(rect);

    [self layoutIfNeeded];
    [self scrollRectToVisible:rect animated:YES];
}

- (void)setText:(NSString *)text;
{
    // TODO: Report radar.
    // -[UITextView setText:] is calling -setAttributedText: with attributes in the original string, preserving autodetected links.
    // This is undesirable, so we build an attributed string here with only the font attribute and call -setAttributedText directly.
    
    if (text != nil) {
        NSDictionary *textAttributes = @{ NSFontAttributeName: self.font };
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:textAttributes];
        [self setAttributedText:attributedText];
    } else {
        [self setAttributedText:nil];
    }
    
    self.selectedRange = NSMakeRange(0, 0);
    
    // Starting with iOS 7, the text storage is exposed.
    // To catch all cases of the text changing (and possibly needing to draw the placeholder string), we'd have to watch the storage.
    // OmniFocus doesn't use the text view that way, so we ignore that.
    [self setNeedsDisplay];
}

- (void)setAttributedText:(NSAttributedString *)attributedText;
{
    [super setAttributedText:attributedText];
    
    // Starting with iOS 7, the text storage is exposed.
    // To catch all cases of the text changing (and possibly needing to draw the placeholder string), we'd have to watch the storage.
    // OmniFocus doesn't use the text view that way, so we ignore that.
    [self setNeedsDisplay];
}

- (BOOL)resignFirstResponder;
{
    BOOL result = [super resignFirstResponder];
    
    if (result && _detectsLinks) {
        // Set editable to NO when resigning first responder so that links are tappable.
        self.editable = NO;
        self.dataDetectorTypes = UIDataDetectorTypeAll;
    }
    
    return result;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesEnded:touches withEvent:event];
    
    // If we got to -touchesEnded, then a link was NOT tapped.
    // Move the insertion point underneath the touch, and become editable and firstRsponder
    
    [self _becomeEditableWithTouches:touches makeFirstResponder:YES];
}

#pragma mark UIScrollView subclass

- (void)setContentOffset:(CGPoint)contentOffset;
{
    [super setContentOffset:contentOffset];
    
    if ([self _shouldDrawPlaceholder]) {
        [self setNeedsDisplay];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
{
    [super setContentOffset:contentOffset animated:animated];
    
    if ([self _shouldDrawPlaceholder]) {
        [self setNeedsDisplay];
    }
}

- (void)setContentInset:(UIEdgeInsets)contentInset;
{
    [super setContentInset:contentInset];
    
    if ([self _shouldDrawPlaceholder]) {
        [self setNeedsDisplay];
    }
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset;
{
    [super setTextContainerInset:textContainerInset];
    
    if ([self _shouldDrawPlaceholder]) {
        [self setNeedsDisplay];
    }
}

#pragma mark Private

- (BOOL)_shouldDrawPlaceholder;
{
    return (![self isFirstResponder] && ![self hasText] && _drawsPlaceholder && ![NSString isEmptyString:_placeholder]);
}

- (void)_becomeEditableWithTouches:(NSSet *)touches makeFirstResponder:(BOOL)makeFirstResponder;
{
    if (![self isEditable]) {
        OBASSERT([touches count] == 1); // Otherwise, we are using a random one

        NSLayoutManager *layoutManager = self.layoutManager;
        NSTextContainer *textContainer = self.textContainer;
        
        // UITextView used to remove the link attributes when setting `dataDetectorTypes` to `UIDataDetectorTypeNone`.
        // It no longer does this, so we do it here. We don't want live links when editing. Leaving them live exposes underlying user interaction bugs in UITextView where the link range is extended inappropriately.
        NSTextStorage *textStorage = self.textStorage;
        [textStorage removeAttribute:NSLinkAttributeName range:NSMakeRange(0, textStorage.length)];
        [layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, textStorage.length)];

        // Offset the touch for the text container insert
        CGPoint point = [[touches anyObject] locationInView:self];
        UIEdgeInsets textContainerInset = self.textContainerInset;
        point.y -= textContainerInset.top;
        point.x -= textContainerInset.left;
        
        NSString *text = self.text;
        NSUInteger characterIndex = [layoutManager characterIndexForPoint:point inTextContainer:textContainer fractionOfDistanceBetweenInsertionPoints:NULL];
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(characterIndex, 0)];
        
        // Replicate UITextView's behavior where it puts the insertion point before/after the word clicked in.
        // We choose the nearest end based on character distance, not pixel distance.
        
        __block BOOL didSetSelectedRange = NO;
        NSStringEnumerationOptions options = (NSStringEnumerationByWords | NSStringEnumerationLocalized);
        [text enumerateSubstringsInRange:lineRange options:options usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            if (NSLocationInRange(characterIndex, enclosingRange)) {
                *stop = YES;
                if (characterIndex - enclosingRange.location < NSMaxRange(enclosingRange) - characterIndex) {
                    self.selectedRange = NSMakeRange(substringRange.location, 0);
                    didSetSelectedRange = YES;
                } else {
                    if (NSMaxRange(enclosingRange) < text.length) {
                        unichar character = [text characterAtIndex:NSMaxRange(enclosingRange)];
                        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:character]) {
                            enclosingRange.length -= 1;
                        }
                    }
                    self.selectedRange = NSMakeRange(NSMaxRange(enclosingRange), 0);
                    didSetSelectedRange = YES;
                }
            }
        }];
        
        // If we didn't set the selected range above, we probably clicked on an empty line
        if (!didSetSelectedRange) {
            self.selectedRange = NSMakeRange(characterIndex, 0);
        }

        self.editable = YES;
        self.dataDetectorTypes = UIDataDetectorTypeNone;

        if (makeFirstResponder) {
            [self becomeFirstResponder];
        }
    }
}

- (void)_addEditingObserversIfNecessary;
{
    if (!_observingEditingNotifications) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(_OUINoteTextView_textDidBeginEditing:) name:UITextViewTextDidBeginEditingNotification object:self];
        [nc addObserver:self selector:@selector(_OUINoteTextView_textDidEndEditing:) name:UITextViewTextDidEndEditingNotification object:self];
        
        _observingEditingNotifications = YES;
    }
}

- (void)_OUINoteTextView_textDidBeginEditing:(NSNotification *)notificaton;
{
    [self setNeedsDisplay];
}

- (void)_OUINoteTextView_textDidEndEditing:(NSNotification *)notificaton;
{
    [self setNeedsDisplay];
}

@end
