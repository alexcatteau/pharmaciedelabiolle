# Parla

**Application iOS pour les gens qui comprennent une langue mais n'arrivent pas à la parler.**

Enfants et petits-enfants d'immigrés, conjoints, expatriés de longue date : ils suivent
une conversation sans effort, lisent, regardent les films sans sous-titres — et se
figent dès qu'ils doivent produire trois phrases. Duolingo ne leur sert à rien : il
leur réapprend « la pomme » alors que leur problème est de ne pas savoir dire
« je me suis débrouillé ».

---

## Le diagnostic, et pourquoi il change tout

Les apps grand public traitent l'apprenant sur **un seul axe** : un niveau, de A1 à C2.
Ce modèle est faux pour ce public. Ici le profil est asymétrique — typiquement **C1 en
compréhension, A2 en production**. Toute app calibrée sur la moyenne des deux les ennuie
*et* les laisse muets.

Trois conséquences, qui sont l'architecture du produit :

| Le problème réel | Ce que fait Parla | Ce que font les autres |
|---|---|---|
| Comprendre ≠ produire | Deux niveaux stockés séparément (`UserProfile.comprehension` / `.production`) ; seul le second progresse | Un seul niveau, un seul parcours |
| L'erreur signature est le **calque du français**, pas le vocabulaire | Catégorie `calque` de première classe dans les corrections, priorisée dans les révisions | Corrections génériques par type grammatical |
| Le vrai plafond, ce sont les **évitements** — ce qu'on voulait dire et qu'on a remplacé par plus plat | Section `avoidedExpressions` du débrief : la partie la plus précieuse, et invisible de toute correction classique | Rien : un évitement n'est pas une faute, donc jamais relevé |

## Les partis pris, et ce qu'ils coûtent

Chacun est un choix assumé, pas un raccourci d'implémentation.

**Aucune correction pendant que tu parles.** L'interlocuteur ne corrige jamais, ne
commente jamais l'accent, ne félicite jamais le niveau. Corriger en direct réinstalle
exactement la peur de mal dire qu'on essaie de désamorcer. Tout arrive après avoir
raccroché. *(`Prompts.interlocutor`, règles 1 et 2)*

**Pas de bouton « parler ».** Le micro s'ouvre seul quand l'interlocuteur se tait, et se
ferme après 1,4 s de silence. Un bouton push-to-talk ramène la posture d'exercice ; le
silence ramène celle d'une conversation. *(`SpeechRecognizer.silenceThreshold`,
`ConversationEngine.openMicrophone`)*

**Le texte est masqué par défaut.** Lire au lieu d'écouter est la béquille numéro un de
ce public — il comprend l'écrit trop bien pour résister. Les sous-titres existent, mais
il faut aller les chercher. *(`ConversationView.showsSubtitles`)*

**La révision se fait à l'oral, sous chrono.** Un QCM mesure la reconnaissance ; or ce
public est déjà excellent en reconnaissance. Une carte n'est validée que si elle a été
**dite**. *(`DrillView`, `ErrorCard.spokenSuccesses`)*

**Le contenu de révision est le corpus des ratés personnels.** Aucune liste de
vocabulaire générique n'entre jamais dans le carnet : uniquement les corrections et les
évitements des conversations réelles. *(`DebriefService.makeCards`)*

**Ni XP, ni ligue, ni mascotte.** Les métriques de jeu marchent sur des enfants et des
débutants ; sur un adulte qui sait déjà qu'il stagne, elles sonnent faux. On affiche
trois chiffres vrais : l'écart compréhension/production, le **temps de latence avant de
répondre** (le meilleur indicateur unique du blocage, et celui qui baisse le plus vite),
et le temps réellement passé à parler. *(`ProgressView_Parla`)*

**Les scénarios sont des situations où l'on a déjà échoué**, pas des thèmes lexicaux.
« Le repas de famille où tout le monde parle vite », « on t'a mal compris et tu dois te
reprendre », « dire à quelqu'un que ça ne va pas ». Chacun embarque des **imprévus**
(`curveballs`) que l'interlocuteur doit placer, pour empêcher de réciter un texte
préparé. *(`ScenarioLibrary`)*

---

## Lancer le projet

```bash
open apps/parla-ios/Parla.xcodeproj
```

Xcode 16+, iOS 17+. Aucune dépendance externe, aucun `pod install`, aucun SPM :
tout est en Foundation / SwiftUI / AVFoundation / Speech.

Le projet utilise les *file system synchronized groups* d'Xcode 16 : ajouter un fichier
dans `Parla/` suffit, il n'y a pas de `project.pbxproj` à éditer.

**L'app se lance sans aucune configuration** : sans clé ni proxy, elle bascule sur
`MockTransport` (réponses italiennes simulées + un débrief complet) et affiche une
bannière « mode démo ». Tout le parcours est parcourable ainsi, y compris au simulateur.

### Brancher le vrai modèle

```bash
cp apps/parla-ios/Config.example.plist apps/parla-ios/Parla/Config.plist
```

puis renseigner **soit** `PARLA_PROXY_URL` (production), **soit** `ANTHROPIC_API_KEY`
(développement uniquement — ignoré en Release).

Sur simulateur, `ANTHROPIC_API_KEY` peut aussi venir de l'environnement du schéma Xcode.

### ⚠️ Ne shippe pas ta clé

Une clé API dans un binaire iOS **est extractible**, quel que soit l'obfuscation. Ce
n'est pas un risque théorique : c'est la première chose que fait quiconque décompresse
un `.ipa`. En production, `ProxyTransport` appelle **ton** backend, qui détient la clé,
authentifie l'utilisateur et applique tes quotas. Le corps envoyé est exactement celui
de l'API Messages — ton proxy peut se contenter de le relayer après vérification.

C'est aussi ce qui te permet de facturer : sans quota côté serveur, un abonné peut te
coûter cent fois son abonnement.

---

## Architecture

```
Parla/
├── Models/            Types purs, Codable, sans dépendance UI
├── Services/
│   ├── Anthropic/     Client API : types wire, transports, streaming SSE, mock
│   ├── Speech/        SFSpeechRecognizer, AVSpeechSynthesizer, session audio
│   ├── Prompts.swift  ← le vrai code métier : personas, règles, schéma du débrief
│   ├── ConversationEngine.swift   Boucle voix → micro → modèle → voix
│   ├── DebriefService.swift       Analyse post-conversation + génération des cartes
│   ├── ScenarioLibrary.swift      Le contenu, en Swift pour être relu en revue de code
│   ├── FluencyAnalyzer.swift      Métriques calculées sur l'appareil, sans réseau
│   ├── SRSScheduler.swift         SM-2, avec validation orale obligatoire
│   └── AppState.swift             Source de vérité unique, injectée dans l'environnement
├── Core/DesignSystem/ Palette, typographie, composants
└── Features/          Onboarding · Accueil · Conversation · Débrief · Carnet · Progrès
```

### La boucle de conversation

```
ConversationEngine.start()
   └─ streamReply (SSE)  ──► SpeechSynthesizer.feed(chunk)
                                  │  découpe en phrases et parle dès la 1re phrase complète
                                  ▼
                          onFinishedSpeaking
                                  ▼
                          SpeechRecognizer.startListening()
                                  │  1,4 s de silence
                                  ▼
                          onTurnEnded(texte, latence, durée)
                                  ▼
                          nouveau tour → streamReply…
```

Le point qui fait la différence perceptive : la synthèse démarre à la **première phrase
complète** reçue, pas à la fin de la réponse. Attendre la réponse entière ajoute une à
deux secondes de blanc par tour — c'est précisément ce qui fait qu'un dialogue
synthétique sonne faux.

### Choix côté API

| Décision | Pourquoi |
|---|---|
| `claude-opus-5` partout | La finesse de la correction linguistique **est** le produit. La latence se règle avec `effort`, pas en descendant de modèle. |
| `effort: "low"` sur les tours de parole | Deux secondes de silence en trop cassent l'illusion de conversation. |
| `effort: "high"` sur le débrief | L'utilisateur a raccroché, il attend un rapport : c'est là que se joue le retour. |
| `max_tokens: 1024` sur les tours | Un tour parlé fait deux ou trois phrases. Le plafond bas empêche aussi le modèle de partir en monologue de professeur. |
| Sortie structurée (`output_config.format`) pour le débrief | Le décodage tombe directement dans `Debrief` — aucun parsing de texte libre. |
| Prompt système mis en cache (`cache_control`) | Persona + scénario + profil sont identiques à chaque tour d'une session : le cache divise le coût d'entrée. |
| `fallbacks: "default"` | Les scénarios de dispute ou de santé peuvent déclencher un refus de classifieur ; le repli serveur évite un échec visible en pleine conversation. |
| Métriques calculées sur l'appareil | Débit, latence, longueur des tours sont **mesurables** : le modèle n'a pas à inventer des chiffres. |

---

## État actuel

Fonctionnel de bout en bout : onboarding → sélection du scénario → conversation orale
mains libres → débrief structuré → carnet d'erreurs → révision orale espacée → progrès.

**Pas encore fait, par ordre d'importance :**

1. **Le proxy backend.** Bloquant pour toute distribution. Sans lui, pas de clé, pas de
   quotas, pas d'abonnement.
2. **Analyse de la prononciation.** `SFSpeechRecognizer` rend du texte, pas un score de
   prosodie. Pour du shadowing sérieux il faudra un service dédié ou un modèle audio.
3. **Voix.** `AVSpeechSynthesizer` est correct et gratuit, mais les voix cloud
   récentes sont nettement plus naturelles. À arbitrer contre le coût par minute.
4. **Dialectes arabes.** `ar-SA` transcrit mal la darija ou l'algérien. Le public visé
   parle des dialectes, pas l'arabe littéraire : c'est un chantier à part entière, pas
   une variante de prompt.
5. **Tests.** Aucun pour l'instant. Les premiers à écrire : `SRSScheduler`,
   `FluencyAnalyzer`, `SpeechSynthesizer.extractSentence`.
6. Synchronisation multi-appareils (`Store` → SwiftData + CloudKit).
