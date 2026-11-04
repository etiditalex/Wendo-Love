"use client";

import { createContext, useContext, useEffect, useState } from "react";

export type Lang = "en" | "sw";

const storageKey = "wendo.lang";

const copy = {
  en: {
    home: "Home",
    messages: "Messages",
    activity: "Activity",
    interests: "Interests",
    views: "Views",
    favorites: "Favorites",
    upgrade: "About Plus",
    hi: "Hi",
    nextStep: "Next step: complete your match criteria",
    learnMembership: "About Wendo Plus",
    matches: "Matches",
    mutual: "Mutual Matches",
    reverse: "Reverse Matches",
    online: "Online",
    popular: "Popular",
    newest: "Newest members",
    latestPhotos: "Latest Photos",
    inArea: "In My Area",
    bodyStyle: "Body style",
    education: "Education",
    age: "Age",
    seeking: "Seeking",
    lockedLists: "Mutual and reverse matches open after you add your gender, who you hope to meet, a city, and a photo.",
    lockedFilters: "Body style and education filters stay locked until an admin activates Wendo Plus for your account.",
    plusInactive: "Wendo Plus is not available to buy on the site yet. An admin will activate or deactivate it later from the dashboard.",
    filtersSoon: "Those filters open when an admin activates Wendo Plus.",
    completeProfile: "Complete match criteria",
    seeUpgrade: "About Wendo Plus",
    noMembers: "No members in this view yet. Try another filter.",
    prev: "Previous",
    next: "Next",
    page: "Page",
    english: "English",
    swahili: "Kiswahili",
  },
  sw: {
    home: "Nyumbani",
    messages: "Ujumbe",
    activity: "Shughuli",
    interests: "Mapendeleo",
    views: "Mitazamo",
    favorites: "Vipendwa",
    upgrade: "Kuhusu Plus",
    hi: "Habari",
    nextStep: "Hatua inayofuata: kamilisha vigezo vya mechi",
    learnMembership: "Kuhusu Wendo Plus",
    matches: "Mechi",
    mutual: "Mechi za pande zote",
    reverse: "Mechi zilizokupenda",
    online: "Mtandaoni",
    popular: "Maarufu",
    newest: "Wanachama wapya",
    latestPhotos: "Picha mpya",
    inArea: "Karibu nami",
    bodyStyle: "Umbo",
    education: "Elimu",
    age: "Umri",
    seeking: "Natafuta",
    lockedLists: "Mechi za pande zote na zilizokupenda hufunguka ukiweka jinsia, unayemtafuta, jiji, na picha.",
    lockedFilters: "Vichujio vya umbo na elimu vinabaki vikiwa vimefungwa hadi msimamizi awashe Wendo Plus.",
    plusInactive: "Wendo Plus bado haipatikani kununuliwa kwenye tovuti. Msimamizi atawasha au kuzima baadaye kutoka dashibodi.",
    filtersSoon: "Vichujio hivyo hufunguka msimamizi anapowasha Wendo Plus.",
    completeProfile: "Kamilisha vigezo",
    seeUpgrade: "Kuhusu Wendo Plus",
    noMembers: "Hakuna wanachama katika mwonekano huu. Jaribu kichujio kingine.",
    prev: "Iliyotangulia",
    next: "Inayofuata",
    page: "Ukurasa",
    english: "English",
    swahili: "Kiswahili",
  },
} as const;

export type CopyKey = keyof (typeof copy)["en"];

const LangContext = createContext<{ lang: Lang; setLang: (lang: Lang) => void }>({
  lang: "en",
  setLang: () => undefined,
});

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>("en");

  useEffect(() => {
    const saved = window.localStorage.getItem(storageKey);
    if (saved === "sw" || saved === "en") setLangState(saved);
  }, []);

  function setLang(next: Lang) {
    setLangState(next);
    window.localStorage.setItem(storageKey, next);
  }

  return <LangContext.Provider value={{ lang, setLang }}>{children}</LangContext.Provider>;
}

export function useLang() {
  const { lang, setLang } = useContext(LangContext);
  return {
    lang,
    setLang,
    t: (key: CopyKey) => copy[lang][key],
  };
}
