# Test Technique

Kactus est une marketplace B2B où les entreprises peuvent profiter de la meilleure expérience de réservation pour leurs événements professionnels.

La plateforme jouit d'un catalogue de plus de 8 000 lieux partenaires, triés sur le volet afin de satisfaire tous les besoins événementiels de ses clients. Ces partenaires ont accès à un espace dédié où ils peuvent gérer leur relation contractuelle avec Kactus ainsi que les fiches des lieux qu'ils référencent. Quand une demande de réservation arrive dans le dashboard du partenaire, celui-ci édite un devis sur son logiciel avant d'uploader le devis sur Kactus pour l'envoyer au client.

Pour entretenir la relation privilégiée que nous avons avec nos partenaires et leur simplifier la vie, nous décidons de développer notre propre éditeur de devis intégré directement dans la plateforme.

Note : Le projet décrit dans ce test a déjà été conduit et optimisé chez Kactus. De plus il ne représente qu'une version réduite des fonctionnalités que nous proposons. Nous ne nous servons pas du code fourni par nos candidats pour développer cet éditeur de devis.

# Livrables

- Une application Rails (avec Stimulus) qui correspond aux besoins fonctionnels décrits ci-dessous. L'UI n'est pas évaluée ici, on demande seulement de respecter l'UX décrite dans les besoins fonctionnels.
- Un README.md en anglais détaillant les étapes nécessaires pour la mise en route de l'application, ainsi que toute autre information que tu juges utile.

Une fois le test terminé, mets simplement le repo en public et envoie-moi le lien. Le choix du format du document pour la partie "amélioration" est libre.

# Besoins fonctionnels

Un devis a un nom. Il est composé d'items. Chaque item a au moins :

- un nom
- une quantité
- un prix unitaire hors taxe
- un taux de TVA

En tant qu'utilisateur de l'éditeur de devis, je peux :

- Lister mes devis créés
- Ajouter un nouveau devis
- Éditer un devis
- Détruire un devis
- Valider un devis : un devis validé ne peut plus être modifié ou supprimé.
- Voir un devis particulier, avec la liste de ses items et les totaux suivants :
  - Total Hors Taxe
  - Total TVA
  - Total TTC
- Ajouter des items à un devis
- Éditer un item
- Détruire un item d'un devis

Deux écrans sont à développer, un premier pour lister les devis, le second pour en afficher un. Toutes les interactions sur les items devront avoir lieu sur l'écran du devis. Tu trouveras le visuel de la mise en page attendue sur ce Figma : https://www.figma.com/design/jiNniIBnQWBxUOJzt6Ihbu/Test-technique

# Évaluation du test

Voici quelques pistes qui pourront t'aiguiller lors de ce test pour comprendre l'évaluation que nous en faisons :

- Le code doit être au niveau d'une mise en production et donc respecter les meilleures pratiques actuelles en termes de développement.
- Préférer la qualité à la quantité.
- Ne pas oublier de te relire, nous accordons beaucoup d'importance à la communication écrite.
