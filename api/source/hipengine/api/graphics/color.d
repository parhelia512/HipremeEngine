/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/

module hipengine.api.graphics.color;
struct HipColor
{
    float r =0, g = 0, b = 0, a = 0;

    this(float r, float g, float b, float a)
    {
        this.r=r;this.g=g;this.b=b;this.a=a;
    }

    static HipColor fromInt(int color)
    {
        return HipColor(
            cast(float)(color >> 24)/255,
            cast(float)((color >> 16) & 255)/255,
            cast(float)((color >> 8) & 255)/255,
            cast(float)(color & 255)/255
        );
    }

    static enum white   = HipColor(1,1,1,1);
    static enum black   = HipColor(0,0,0,0);
    static enum red     = HipColor(1,0,0,1);
    static enum green   = HipColor(0,1,0,1);
    static enum blue    = HipColor(0,0,1,1);
    static enum yellow  = HipColor(1,1,0,1);
    static enum purple  = HipColor(1,0,1,1);
    static enum teal    = HipColor(0,1,1,1);
}
