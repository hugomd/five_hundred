# About this project

## Overview

500 is a 4-player trick-taking card game played in fixed partnerships. The game features bidding, trump selection, and a scoring system based on performance against the bid.

This document describes the rules, mechanics, and data requirements for implementing 500.
Game Structure
Players

    Total: 4

    Teams: Player 0 & 2 vs Player 1 & 3

    Turn order: Clockwise

    Partnership: Fixed

## Deck

Composition (43 Cards Total)
Suit	Cards
♠, ♥, ♦, ♣	7, 8, 9, 10, J, Q, K, A
Jacks	All 4 Jacks included
Joker	Highest trump card

    Note: No 2s–6s except Jacks.

## Trump Order (if suit is trump)

    Joker (highest)

    Right Bower – Jack of trump suit

    Left Bower – Jack of same-color suit

    A, K, Q, 10, 9, 8, 7 (in trump suit)

## Non-Trump Order

    A (high), K, Q, J, 10, 9, 8, 7

## Phases

1. Deal

    Each player receives 10 cards

    3 cards go to the kitty (face down)

2. Bidding

    Clockwise from left of dealer

    Players may bid or pass

    Bids are: (6–10 tricks) + suit or No Trump

    Each bid must be higher:

        More tricks, or

        Same tricks but higher-ranked suit

Suit Ranking (Low → High)

Clubs < Diamonds < Hearts < Spades < No Trump

Example Bids

    6♠, 7♣, 8 No Trump

Pass Out Rule

    If all players pass: redeal (or optional misère variant)

3. Declarer & Kitty

    Highest bidder = declarer

    Adds 3 kitty cards, discards any 3 cards

    Declares trump suit (as bid)

4. Playing Tricks

    Player to dealer's left leads

    Players must follow suit if possible

    If not, may play trump or any card

    Trick is won by:

        Highest trump, or

        Highest card in suit led if no trump played

5. Scoring
Declarer's Team

    Success (bid fulfilled): Add bid points

    Failure (bid missed): Subtract bid points

Defenders (optional rule)

    May receive 10 points per trick

Winning

    First team to ≥ 500 points wins

    A team with ≤ -500 loses

Bid Values Table
Tricks	Clubs	Diamonds	Hearts	Spades	No Trump
6	40	60	80	100	120
7	140	160	180	200	220
8	240	260	280	300	320
9	340	360	380	400	420
10	440	460	480	500	520

# Game Concepts

## Game State

    Players: list of player IDs (0–3)

    Hands: list of 10 cards per player

    Kitty: 3-card stack

    Bidding history

    Current bid (tricks, suit, bidder)

    Trick history (lead suit, plays, winner)

    Scores (team 1 vs team 2)

## Validation Rules

    Bids must outbid prior bid

    Cannot play out of turn

    Must follow suit if possible

    Only declarer touches the kitty

## Optional Rules (Extensions)

    Misère: Bid to win zero tricks

    Open Misère: Cards are revealed after lead

    Defender scoring

    Bidding to 500 cap: Exact score to win

# Environment set up
Before running anything, ensure Hermit has been activated by running:
. ./bin/activate-hermit

# Compiling

You can compile code with:
mix compile

If this fails, there are likely syntax errors.
