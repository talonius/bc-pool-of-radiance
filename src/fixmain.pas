{ Program entry: initialize the game, bring the merged data archives up to date, show the introduction and the
  startup advisory (#1173), run CharGen's main menu, then run the game loop and shut down. }
{$F+}
{$I COMPILER.INC}
program FixMain;

{ Natively SdlHost comes first: its window is open before any other unit's initialization runs. }
uses {$IFDEF FPC}{$IFDEF UNIX}CThreads, {$ENDIF}SdlHost, SdlSound, {$ENDIF}Types,
  {$IFNDEF FPC}Overlay, {$ENDIF}Crt, Dos,
  GameDefs, GameVars,
  SoundDrv, GameIo, DaxIo, TextRend, Blit, {$IFNDEF FPC}VidCga, VidEga, VidTdy, {$ENDIF}VidVga, GameBoot,
  Sym8x8, Border, Debug, MapTiles, CbtMap, Pathing, View3D, Portrait, Wilds, MapView,
  MenuCore, CharHlp, CharDisp, FxEngine, ClassCal, Magic, Money, MoneyCal, RandItem, GameTime, ViewChar, Ending,
  VidOps, PicCga, PicEga, PicTdy, PicVga, UsualSpl, SaveLoad, CharGen, Camp,
  Journal1, Journal2, Journal3, Journal4, JrnlList, JrnlQst, JrnlView, Options, CbtLog, LogWrap, LogView,
  Explore, CbtActs, EffHndlr, GameInit, CombatSt, CombatAi, Combat, EclVars, EclMenu, Shop, ShopBuy, PostCbt, TownCore,
  Temple, EclVm, BldShow, DataPat, DataBld, Intro, HeapErr, SaveMenu, AreaName, Vault, VaultMnu, EclTrace, KeyHelp,
  Advisory, Demo, CbtMini, WideView;

{$O Demo}
{$O WideView}
{$O Advisory}
{$O CbtMini}
{$O AdvPlan}
{$O EclTrace}
{$O Vault}
{$O VaultMnu}
{$O AreaName}
{$O SaveMenu}
{$O HeapErr}
{$O Intro}
{$O DataPat}
{$O DataBld}
{$O BldShow}
{$O EclVm}
{$O Temple}
{$O TownCore}
{$O PostCbt}
{$O Shop}
{$O ShopBuy}
{$O EclVars}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O Options}
{$O CfgFile}
{$O SfxFile}
{$O LogView}
{$O LogWrap}
{$O JrnlList}
{$O JrnlQst}
{$O JrnlView}
{$O Journal4}
{$O Journal3}
{$O Journal2}
{$O Journal1}
{$O Camp}
{$O FixPlan}
{$O CharGen}
{$O UsualSpl}
{$O VidOps}
{$O PicCga}
{$O PicEga}
{$O PicTdy}
{$O PicVga}
{$O SaveLoad}
{$O Ending}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O MoneyCal}
{$O RandItem}
{$O Magic}
{$O SpellInf}
{$O SpellTxt}
{$O ClassCal}
{$O FxEngine}
{$O CharDisp}
{$O MenuCore}
{$O MapView}
{$O Wilds}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O Debug}
{$O Sym8x8}
{$O CompTool}
{$O EvtKind}
{$O ClueBook}
{$O CharEdit}
{$O CharExt}
{$O ChgClass}
{$O PartyMnu}
{$O KeyHelp}
{$O BeastMnu}
{$O BeastFil}
{$O Sage}
{$O MagicShp}

begin
  GameInit.GameInit2;
  DataBld.BuildDataFiles;
  { STING skips the introduction }
  if not GameVars.stingArg then begin
    Intro.Introduction;
    { the key that skipped the introduction is not a main-menu choice }
    while KeyPressed do
      GameIo.DiscardPendingKeys;
  end;
  { the title theme, still playing under the credits, ends at the main menu (#1070) }
  SoundDrv.StopMusic;
  { before the main menu, with the sound timer gone from the PIT: the speed check, and the startup advisory when one of
    its parts is due (#1173) }
  Advisory.Measure;
  Advisory.Show;
  { the vault of a game left unsaved last time is gone with it }
  Vault.ForgetSessionVault;
  { the main menu's Exit is the way out; a destroyed party ends GameLoop and the game returns to the main menu, and so
    does the demo (#1109), which the main menu starts when it is left alone with no party }
  while True do begin
    CharGen.MainMenu(False, False);
    if GameVars.demoMode then
      Demo.Run
    else begin
      View3D.SetView3DColors(LightCyan, Black, LightGray, Brown);
      EclVm.GameLoop;
      { F8 on the map menu ends GameLoop to load the quick save, and a load from the training hall's party menu ends it
        loaded; the loop then starts again on the loaded game, as it does after a load from the main menu }
      while Explore.quickLoadAsked or (GameVars.loadedSave <> 0) do begin
        if Explore.quickLoadAsked then begin
          Explore.quickLoadAsked := False;
          SaveLoad.QuickLoad;
        end;
        EclVm.GameLoop;
      end;
      { the party was destroyed: a new game starts from the main menu, without the lost party's vault }
      SaveLoad.FreeParty;
      Vault.ForgetSessionVault;
      GameInit.ResetGameState;
    end;
  end;
end.
