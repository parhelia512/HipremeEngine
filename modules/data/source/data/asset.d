/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module data.asset;

/** Controls the asset ids for every game asset
*   0 is reserved for errors.
*/
private __gshared uint currentAssetID = 0;

abstract class HipAsset
{
    /** Use it to insert into an asset pool, alias*/
    string name;
    /**Currently not in use */
    uint assetID;
    ///When it started loading
    float startLoadingTimestamp;
    ///How much time it took to load, in millis
    float loadTime;

    this(string assetName)
    {
        this.name = assetName;
        assetID = ++currentAssetID;
    }

    /** Should return if the load was successful */
    abstract bool load();
    /** Should return if the asset is ready for use*/
    abstract bool isReady();
    /**
    * Action for when the asset finishes loading
    * Proabably be executed on the main thread
    */
    abstract void onFinishLoading();


    void startLoading()
    {
        import util.time;
        startLoadingTimestamp = HipTime.getCurrentTimeAsMilliseconds();
        load();
    }

    void finishLoading()
    {
        import util.time;
        if(isReady())
        {
            onFinishLoading();
            loadTime = HipTime.getCurrentTimeAsMilliseconds() - startLoadingTimestamp;
        }
    }

    /**
    *   Currently, no AssetID recycle is in mind. It will only invalidate
    *   the asset for disposing it on an appropriate time
    */
    final void dispose()
    {
        this.assetID = 0;
        onDispose();
    }
    ///Use it to clear the engine. 
    abstract void onDispose();
}