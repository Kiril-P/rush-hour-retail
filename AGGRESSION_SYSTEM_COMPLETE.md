# Customer Aggression System - Implementation Complete! 😡

## Features Implemented

### 1. **Aggression Trigger System**
- ✅ 40% chance (configurable) for customers to become aggressive when punched
- ✅ Triggered after knockback recovery
- ✅ Customers drop shopping carts when becoming aggressive
- ✅ Smooth state transition: Normal → Knocked Back → Aggressive

### 2. **Chase Behavior**
- ✅ **New "AGGRESSIVE" State**: Customers actively chase the player
- ✅ **NavigationAgent3D Pathfinding**: Continuously updates target to player position
- ✅ **Injured Run Animation**: Uses "Injured Run.fbx" for all 4 characters
- ✅ **Angry Sound**: Plays "Roblox Angry Sound Effect.mp3" when becoming aggressive
- ✅ **Increased Speed**: Chase speed (3.0) faster than normal walk (1.5)
- ✅ **Persistent Anger Particles**: Red floating particles above head while aggressive

### 3. **Player Attack System**
- ✅ **Attack Detection**: When customer gets within 1.5m, they attack
- ✅ **Knockback to Player**: Player gets pushed backward (force: 10.0)
- ✅ **1 Second Stun**: Player movement disabled for 1 second
- ✅ **Stun Visual Effects**:
  - Heavy screen shake (0.8 intensity)
  - Vignette effect (darkens edges of screen)
  - Impact sound (MLG hitmarker)
- ✅ **Post-Attack Calm**: Customer becomes calm after attacking

### 4. **State Management**
States flow: `Normal → Knocked Back → Aggressive → Attacking → Calm`

**Calm Down Conditions:**
- ✅ After successfully attacking player
- ✅ After 15 seconds of chasing (configurable)
- ✅ If player gets more than 20m away
- ✅ If player becomes invalid/unreachable

**Multiple Customers:**
- ✅ System handles multiple aggressive customers simultaneously
- ✅ Each tracks their own aggression state independently
- ✅ Each has their own particle effects and timers

### 5. **Visual & Audio Feedback**

**When Customer Becomes Angry:**
- 🔊 Roblox angry sound effect
- 🎨 Red particle effect above head (continuous)
- 🏃 Injured run animation
- 🛒 Cart drops/disappears

**When Customer Attacks Player:**
- 💥 Heavy screen shake
- 🎯 Player pushed backward
- 🔊 Impact sound
- ⭐ Stun effect (vignette darkening)
- 🚫 Movement disabled for 1 second

**When Customer Calms Down:**
- ❌ Anger particles removed
- 🚶 Returns to normal wandering
- 🔄 Resumes shopping behavior

## Configurable Settings

### Customer AI (`customer_ai.gd`):
- `aggression_chance` = 0.4 (40% chance to get angry)
- `chase_speed` = 3.0 (how fast they chase)
- `attack_range` = 1.5 (distance to attack player)
- `attack_knockback` = 10.0 (force applied to player)
- `calm_down_time` = 15.0 (seconds before giving up)
- `lose_player_distance` = 20.0 (distance where they stop chasing)

## Balance & Gameplay

### Fun vs Fair Balance:
- **40% aggression chance**: Not every punch causes retaliation
- **3.0 chase speed**: Fast enough to catch player if they don't run
- **1 second stun**: Long enough to feel impact, short enough to recover
- **15 second calm timer**: Gives player time to escape or fight back
- **Attack once then calm**: Customers don't spam attacks

### Strategic Gameplay:
- Players can punch customers for fun, but risk retaliation
- Multiple angry customers = chaos!
- Running away is viable (they give up after time)
- Getting stunned near multiple customers is dangerous
- Managing aggression is part of the challenge

## Technical Implementation

### State Machine:
```gdscript
"IDLE" → "WALKING" → "STOPPING" → (punch) → 
"FALLING" → (40% chance) → "AGGRESSIVE" → 
"ATTACKING" → "WALKING"
```

### Animation Loading:
All characters now load 6 animations:
1. Idle (Happy Idle, Breathing Idle, etc.)
2. Walk (Walking, Dwarf Walk, etc.)
3. Walk Cart (shopping_cart_walk.fbx)
4. Fall (Sweep Fall.fbx)
5. **Run (Injured Run.fbx)** - NEW!

### Player Integration:
- `take_customer_attack(velocity, position)` - Public method for customers to call
- Stun system disables all movement inputs
- Knockback uses same physics as items
- Camera effects enhance impact feel

## Testing Checklist

- [x] Customers have chance to become aggressive when punched
- [x] Angry customers chase player with run animation
- [x] Angry sound plays on aggression trigger
- [x] Red particles appear above angry customer's head
- [x] Shopping carts are dropped when becoming aggressive
- [x] Customers attack when close enough
- [x] Player gets knocked back and stunned
- [x] Screen shakes and vignette appears during stun
- [x] Player movement disabled during stun
- [x] Customers calm down after attacking
- [x] Customers calm down if player escapes
- [x] Multiple angry customers work simultaneously
- [x] No errors or crashes

## What Makes It Fun

1. **Risk vs Reward**: Punching is fun, but consequences exist
2. **Emergent Chaos**: Multiple angry customers = hilarious chaos
3. **Fair Counterplay**: Players can run, dodge, or fight back
4. **Clear Feedback**: Visual and audio cues make everything clear
5. **Balanced Timer**: Not too punishing, but not ignorable

Enjoy the chaos! 😈🥊👊

## Pro Tips for Players

- Don't punch too many customers at once
- If one gets angry, RUN or prepare for a fight
- Use sprint to outrun aggressive customers
- Getting cornered by multiple angry customers = bad time
- The stun is short but dangerous if more customers are nearby
- Customers eventually forgive and forget... eventually
