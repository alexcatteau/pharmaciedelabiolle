import Foundation

/// Catalogue des scénarios.
///
/// Écrit en Swift plutôt qu'en JSON embarqué : le contenu est le produit, il doit
/// être relu en revue de code comme du code. Le jour où un back-office existe,
/// ce type devient un cache local et rien d'autre ne bouge.
///
/// Règle de rédaction : chaque scénario décrit un moment où quelqu'un s'est déjà
/// senti mal. Pas un thème lexical.
enum ScenarioLibrary {

    static let all: [Scenario] = [

        // MARK: Famille

        Scenario(
            id: "famille-repas",
            category: .family,
            title: "Le repas de famille où tout le monde parle vite",
            situation: "Tu es à table chez ta tante. Elle te parle sans ralentir, comme aux autres, et attend de vraies réponses — pas des hochements de tête.",
            interlocutor: Interlocutor(
                name: "Zia Rosa",
                persona: "La tante de 62 ans. Chaleureuse, curieuse, un peu envahissante. Elle enchaîne les questions sur ta vie, ton travail, si tu manges assez. Elle coupe la parole. Elle ne ralentit jamais parce que « tu comprends très bien ».",
                register: .familiar,
                speechRate: 1.05
            ),
            objective: "Raconter ce que tu fais dans la vie et donner des nouvelles, sans jamais répondre en français.",
            productionLevel: .a2,
            motivations: [.family, .identity],
            languages: [],
            curveballs: [
                "Demander pourquoi la personne ne parle pas mieux la langue alors qu'elle a grandi avec",
                "Poser une question sur un souvenir d'enfance précis que la personne devra raconter au passé",
                "Changer brusquement de sujet pour parler d'un cousin dont la personne n'a jamais entendu parler"
            ],
            targetMinutes: 5
        ),

        Scenario(
            id: "famille-annonce",
            category: .family,
            title: "Annoncer une nouvelle qui ne va pas plaire",
            situation: "Tu dois annoncer que tu ne viendras pas cet été. En face, on va insister, se vexer, culpabiliser. Tu dois tenir ta position — dans la langue.",
            interlocutor: Interlocutor(
                name: "Mamma",
                persona: "Ta mère. Elle prend la nouvelle personnellement, soupire, sort un « fai come vuoi » qui veut dire l'inverse. Elle n'est pas méchante, mais elle négocie.",
                register: .familiar,
                speechRate: 1.0
            ),
            objective: "Maintenir ta décision tout en restant affectueux — et sans passer au français quand ça devient tendu.",
            productionLevel: .b1,
            motivations: [.family],
            languages: [],
            curveballs: [
                "Culpabiliser en évoquant l'âge et la santé",
                "Proposer un compromis inattendu qui oblige à réfléchir en direct"
            ],
            targetMinutes: 6
        ),

        // MARK: Quotidien

        Scenario(
            id: "quotidien-pharmacie",
            category: .everyday,
            title: "Décrire un symptôme à la pharmacie",
            situation: "Tu ne te sens pas bien et tu dois expliquer quoi, précisément. Le vocabulaire du corps est celui qu'on n'apprend jamais en famille.",
            interlocutor: Interlocutor(
                name: "Il farmacista",
                persona: "Pharmacien pressé mais consciencieux. Il pose des questions fermées et précises, et demande des détails que tu n'as pas anticipés.",
                register: .neutral,
                speechRate: 1.0
            ),
            objective: "Décrire ton symptôme assez précisément pour repartir avec le bon produit.",
            productionLevel: .a2,
            motivations: [.travel, .admin],
            languages: [],
            curveballs: [
                "Demander depuis combien de temps, et si la personne prend déjà un traitement",
                "Proposer deux produits et demander de choisir en justifiant"
            ],
            targetMinutes: 4
        ),

        Scenario(
            id: "quotidien-malentendu",
            category: .everyday,
            title: "On t'a mal compris — tu dois te reprendre",
            situation: "Tu as commandé, le serveur a compris autre chose. C'est le moment exact que tout le monde redoute : il faut reformuler, à voix haute, devant du monde.",
            interlocutor: Interlocutor(
                name: "Il cameriere",
                persona: "Serveur de 25 ans, débit rapide, un peu débordé. Il répète ce qu'il a compris et attend confirmation. Il n'est pas désagréable, juste pressé.",
                register: .neutral,
                speechRate: 1.15
            ),
            objective: "Corriger le malentendu et obtenir ce que tu voulais vraiment.",
            productionLevel: .a2,
            motivations: [.travel],
            languages: [],
            curveballs: [
                "Répéter une version encore fausse de la commande",
                "Proposer une alternative qui n'était pas prévue et demander une décision immédiate"
            ],
            targetMinutes: 4
        ),

        Scenario(
            id: "quotidien-telephone",
            category: .everyday,
            title: "Un appel téléphonique, sans les gestes",
            situation: "Au téléphone, tu n'as ni le visage ni les mains pour t'aider. C'est le format le plus dur, et le meilleur test.",
            interlocutor: Interlocutor(
                name: "Reception",
                persona: "Standardiste d'un cabinet. Parle vite, en formules toutes faites. Demande des informations précises : nom épelé, date, motif.",
                register: .formal,
                speechRate: 1.1
            ),
            objective: "Prendre un rendez-vous et confirmer la date et l'heure sans te tromper.",
            productionLevel: .b1,
            motivations: [.admin, .travel],
            languages: [],
            curveballs: [
                "Demander d'épeler le nom de famille",
                "Annoncer qu'il n'y a plus de créneau et proposer une alternative à négocier"
            ],
            targetMinutes: 4
        ),

        // MARK: Travail

        Scenario(
            id: "travail-presentation",
            category: .work,
            title: "Expliquer ton travail à quelqu'un du métier",
            situation: "En face, une personne du même secteur. Le registre familial ne sert à rien ici : il faut être précis et structuré.",
            interlocutor: Interlocutor(
                name: "Marco",
                persona: "Collègue d'une filiale, 40 ans, professionnel et direct. Il pose des questions techniques et relance quand une réponse est vague.",
                register: .neutral,
                speechRate: 1.0
            ),
            objective: "Expliquer clairement ce que tu fais et répondre à deux questions de fond.",
            productionLevel: .b1,
            motivations: [.work],
            languages: [],
            curveballs: [
                "Demander de reformuler une explication jugée trop floue",
                "Poser une question sur les chiffres ou les délais"
            ],
            targetMinutes: 6
        ),

        Scenario(
            id: "travail-desaccord",
            category: .work,
            title: "Ne pas être d'accord, poliment",
            situation: "Ton interlocuteur propose quelque chose qui ne marchera pas. Dire non dans une langue qu'on maîtrise mal est le dernier obstacle.",
            interlocutor: Interlocutor(
                name: "Giulia",
                persona: "Cheffe de projet sûre d'elle. Elle défend sa position, demande des arguments, ne se laisse pas convaincre facilement — mais elle écoute.",
                register: .formal,
                speechRate: 1.05
            ),
            objective: "Exprimer ton désaccord et proposer une alternative, sans agressivité ni excuse permanente.",
            productionLevel: .b2,
            motivations: [.work],
            languages: [],
            curveballs: [
                "Demander de chiffrer ou de justifier l'objection",
                "Faire semblant de céder puis revenir à la charge autrement"
            ],
            targetMinutes: 6
        ),

        // MARK: Démarches

        Scenario(
            id: "admin-guichet",
            category: .admin,
            title: "Le guichet et son vocabulaire à lui",
            situation: "Un dossier, un formulaire, un document manquant. Le vocabulaire administratif n'existe dans aucune conversation de famille.",
            interlocutor: Interlocutor(
                name: "L'impiegato",
                persona: "Agent d'accueil, ni aimable ni désagréable. Emploie des termes administratifs exacts et attend des réponses précises. Répète à l'identique si on ne comprend pas.",
                register: .formal,
                speechRate: 1.0
            ),
            objective: "Comprendre ce qui manque à ton dossier et convenir de la suite.",
            productionLevel: .b1,
            motivations: [.admin],
            languages: [],
            curveballs: [
                "Annoncer qu'un document est périmé et qu'il faut revenir",
                "Demander une information personnelle inattendue"
            ],
            targetMinutes: 5
        ),

        // MARK: Situations tendues

        Scenario(
            id: "conflit-reclamation",
            category: .conflict,
            title: "Réclamer, et ne pas lâcher",
            situation: "On t'a facturé quelque chose que tu n'as pas eu. Il faut réclamer — et tenir quand on te dit non.",
            interlocutor: Interlocutor(
                name: "Il responsabile",
                persona: "Responsable qui commence par refuser poliment, invoque le règlement, puis cède si on insiste avec des arguments concrets.",
                register: .formal,
                speechRate: 1.05
            ),
            objective: "Obtenir un geste commercial, ou au minimum une explication claire.",
            productionLevel: .b2,
            motivations: [.travel, .admin],
            languages: [],
            curveballs: [
                "Refuser une première fois en invoquant une règle interne",
                "Demander une preuve que la personne n'a pas sur elle"
            ],
            targetMinutes: 6
        ),

        Scenario(
            id: "conflit-voisin",
            category: .conflict,
            title: "Dire à quelqu'un que ça ne va pas",
            situation: "Le voisin fait du bruit tous les soirs. Tu dois aborder le sujet sans que ça dégénère, dans une langue où tu n'as pas de nuances.",
            interlocutor: Interlocutor(
                name: "Il vicino",
                persona: "Voisin de 50 ans, sur la défensive dès la première phrase. Il minimise, puis se vexe, puis finit par discuter si on reste calme.",
                register: .familiar,
                speechRate: 1.1
            ),
            objective: "Poser le problème et obtenir un accord, sans agressivité.",
            productionLevel: .b2,
            motivations: [.identity, .admin],
            languages: [],
            curveballs: [
                "Nier le problème et retourner l'accusation",
                "Passer au tutoiement agressif pour tester la réaction"
            ],
            targetMinutes: 6
        ),

        // MARK: Vie sociale

        Scenario(
            id: "social-raconter",
            category: .social,
            title: "Raconter une histoire drôle",
            situation: "Le vrai plafond : passer de « je me fais comprendre » à « je suis marrant ». Ça demande du rythme, des temps du passé, une chute.",
            interlocutor: Interlocutor(
                name: "Luca",
                persona: "Ami de ton âge, complice et taquin. Il relance, réagit, se moque gentiment, raconte lui aussi. Il ne laisse pas de blanc.",
                register: .familiar,
                speechRate: 1.15
            ),
            objective: "Raconter une anecdote du début à la fin, avec une chute, sans perdre ton auditoire.",
            productionLevel: .b2,
            motivations: [.social, .identity],
            languages: [],
            curveballs: [
                "Interrompre au milieu de l'histoire avec une question de détail",
                "Enchaîner sur sa propre anecdote et rendre la parole brutalement"
            ],
            targetMinutes: 6
        ),

        Scenario(
            id: "social-rencontre",
            category: .social,
            title: "Une première rencontre",
            situation: "Quelqu'un que tu ne connais pas, qui ne sait rien de toi. Aucun contexte familial pour te rattraper.",
            interlocutor: Interlocutor(
                name: "Chiara",
                persona: "Trente ans, sympathique et curieuse, pose des questions ouvertes, laisse des silences que tu dois combler toi-même.",
                register: .neutral,
                speechRate: 1.05
            ),
            objective: "Tenir dix échanges et repartir avec au moins une chose apprise sur elle.",
            productionLevel: .b1,
            motivations: [.social, .dating],
            languages: [],
            curveballs: [
                "Laisser un silence sans relancer, pour forcer l'initiative",
                "Poser une question sur un avis personnel qui demande de nuancer"
            ],
            targetMinutes: 5
        )
    ]

    static func scenario(id: String) -> Scenario? {
        all.first { $0.id == id }
    }

    /// Sélection pour l'écran d'accueil : ce que la personne est venue chercher,
    /// à un niveau qui la met en difficulté sans la noyer.
    static func recommended(for profile: UserProfile, limit: Int = 6) -> [Scenario] {
        let available = all.filter { $0.isAvailable(for: profile) }

        let matching = available.filter { scenario in
            profile.motivations.isEmpty || !Set(scenario.motivations).isDisjoint(with: profile.motivations)
        }

        // On vise un cran au-dessus du niveau de production : rester à son niveau
        // est confortable et ne fait rien progresser — c'est le reproche exact
        // que l'utilisateur fait aux apps existantes.
        let target = min(profile.production.rank + 1, CEFRLevel.allCases.count - 1)

        return matching
            .sorted { lhs, rhs in
                abs(lhs.productionLevel.rank - target) < abs(rhs.productionLevel.rank - target)
            }
            .prefix(limit)
            .map { $0 }
    }
}
