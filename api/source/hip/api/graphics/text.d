module hip.api.graphics.text;
import hip.api.data.font;
public import hip.math.rect : Size;

/**
 * All the combinations that exists for align, specifies firstly the vertical position, then the horizontal:
 * i.e: centerLeft is center vertical, left horizontally
 */
enum HipTextAlign : ubyte
{
    ///This means leftCenter internally
    defaultAlign = 0,
    centerH = 0b000001,
    left    = 0b000010,
    right   = 0b000100,
    centerV = 0b001000,
    top     = 0b010000,
    bottom  = 0b100000,


    topCenter  = top | centerH,
    topLeft    = top | left,
    topRight   = top | right,

    center     = centerV | centerH,
    centerLeft = centerV | left,
    centerRight= centerV | right,

    botCenter  = bottom | centerH,
    botLeft    = bottom | left,
    botRight   = bottom | right,

    horizontalMask = centerH | left | right,
    verticalMask = centerV | top | bottom,
}

HipTextAlign getAlignH(HipTextAlign input)
{
    return cast(HipTextAlign)(input & HipTextAlign.horizontalMask);
}

HipTextAlign getAlignV(HipTextAlign input)
{
    return cast(HipTextAlign)(input & HipTextAlign.verticalMask);
}

/**
 *
 * Params:
 *   x = Specified X
 *   y = Specified Y
 *   width = The width of the subject
 *   height = The height of the subject
 *   alignment = Alignment for calculating newX and newY
 *   newX = Out arg
 *   newY = Out arg
 *   bounds = The bounds to align to. If It is == 0, it won't be considered in the calculation
 */
void getPositionFromAlignment(
    int x, int y, int width, int height, HipTextAlign alignment,
    out int newX, out int newY, Size bounds
)
{
    with(HipTextAlign)
    {
        switch(getAlignH(alignment))
        {
            case centerH:
                if(bounds.width != 0)
                    newX = (x + (bounds.width)/2) - (width / 2);
                else
                    newX = x - width/2;
                break;
            case right:
                if(bounds.width != 0)
                    newX = x + bounds.width - width;
                else
                    newX = x - width;
                break;
            case left:
                newX = x;
                break;
            default: assert(false, "Some invalid horizontal alignment was received.");
        }
        switch(getAlignV(alignment))
        {
            case centerV:
                if(bounds.height != 0)
                    newY = y + (bounds.height/2) - height/2;
                else
                    newY = y- height/2;
                break;
            case bottom:
                if(bounds.height != 0)
                    newY = y + bounds.height - height;
                else
                    newY = y - height;
                break;
            case top:
                newY = y;
                break;
            default: assert(false, "Some invalid vertical alignment was received.");
        }
    }
}

/**
 *
 * Params:
 *   font = The font used as a reference to build the quad
 *   vertices = Output vertices
 *   text = The text to build the vertices
 *   x = Start X
 *   y = Start Y
 *   depth = Depth for possibly Z buffer
 *   scale = Rescaling the font
 *   align_ = Alignment on where it will show
 *   bounds = -1 value will make it be ignored. If exists, it will be used both for word wrap and for alignment to the size specified
 *   wordWrap = If the text will line-break if it reaches the size too big
 *   shouldRenderSpace = Render ' ' characters or not.
 * Returns:
 */
int putTextVertices(
    IHipFont font, HipTextRendererVertexAPI[] vertices,
    string text,
    int x, int y, float depth, float scale = 1.0f,
    HipTextAlign align_ = HipTextAlign.center,
    Size bounds = Size.init,
    bool wordWrap = false,
    bool shouldRenderSpace
)
{
    int yoffset = 0;
    bool isFirstLine = true;
    int vI = 0;
    int height = cast(int)(font.getTextHeight(text) * scale);

    foreach(HipLineInfo lineInfo; font.wordWrapRange(text, wordWrap ? bounds.width : -1))
    {
        if(!isFirstLine)
        {
            yoffset+= font.lineBreakHeight * scale;
        }
        isFirstLine = false;
        int xoffset = 0;
        int displayX = void, displayY = void;
        int lineYOffset = 0;
        // if(align_ & HipTextAlign.top) lineYOffset = yoffset - cast(int)(lineInfo.minYOffset * scale);
        lineYOffset =  -cast(int)(lineInfo.minYOffset * scale);

        getPositionFromAlignment(
            x, y,
            cast(int)(lineInfo.width * scale), cast(int)(height ? height : lineInfo.height * scale),
            align_,
            displayX, displayY,
            bounds
        );
        for(int i = 0; i < lineInfo.line.length; i++)
        {
            int kerning = lineInfo.kerningCache[i];
            const(HipFontChar)* ch = lineInfo.fontCharCache[i];

            switch(lineInfo.line[i])
            {
                case ' ':
                    if(!shouldRenderSpace)
                    {
                        xoffset+= font.spaceWidth * scale;
                        break;
                    }
                    goto default;
                default:
                    if(ch is null) continue;
                    ch.putCharacterQuad(
                        cast(float)(xoffset+displayX+(ch.xoffset+kerning) *scale),
                        cast(float)(yoffset+displayY+lineYOffset + ch.yoffset*scale), depth,
                        vertices[vI..vI+4], scale
                    );
                    vI+= 4;
                    xoffset+= ch.xadvance*scale;
            }
        }
    }
    return vI;
}
