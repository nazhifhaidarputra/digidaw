//! Typestate state machines, checked at compile time where the state is known and at run
//! time where it is not.

use core::fmt;

/// A run-time transition was requested from a state that does not have it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct InvalidState {
    /// Name of the state the machine was in.
    pub from: &'static str,
    /// Name of the transition that was requested.
    pub transition: &'static str,
}

impl fmt::Display for InvalidState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "transition `{}` is not valid from state `{}`",
            self.transition, self.from
        )
    }
}

impl core::error::Error for InvalidState {}

/// Why a fallible run-time transition did not happen.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransitionError<E> {
    /// The machine was in a state that does not have the transition.
    InvalidState(InvalidState),
    /// The transition was valid but its body failed.
    Failed(E),
}

impl<E> From<InvalidState> for TransitionError<E> {
    fn from(invalid: InvalidState) -> Self {
        Self::InvalidState(invalid)
    }
}

impl<E: fmt::Display> fmt::Display for TransitionError<E> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidState(invalid) => invalid.fmt(f),
            Self::Failed(error) => error.fmt(f),
        }
    }
}

impl<E: fmt::Debug + fmt::Display> core::error::Error for TransitionError<E> {}

/// Runs a consuming run-time transition on a machine held in a field.
///
/// The machine is always put back: the new state on success, the unchanged one on failure.
/// The slot is only ever empty if an earlier transition body panicked, which is reported as an
/// [`InvalidState`].
pub fn transition_in_place<M, E: From<InvalidState>>(
    slot: &mut Option<M>,
    transition: impl FnOnce(M) -> Result<M, (M, E)>,
) -> Result<(), E> {
    let Some(machine) = slot.take() else {
        return Err(E::from(InvalidState {
            from: "lost by a panicking transition",
            transition: "any",
        }));
    };
    match transition(machine) {
        Ok(next) => {
            *slot = Some(next);
            Ok(())
        }
        Err((previous, error)) => {
            *slot = Some(previous);
            Err(error)
        }
    }
}

/// A typestate state-machine generator as a declarative macro (no dependencies).
///
/// What `typestate!` generates from one declaration:
///   * `struct Machine<S> { shared, state: S }`   one wrapper, the state is a type parameter
///   * one data struct per state, plus a readable alias (`PreparedPlugin`)
///   * one consuming method per transition, defined only on the source state
///   * an enum over all states, for storing machines whose state is only known at run time,
///     with the same transitions as run-time checked methods
///
/// Each transition can be taken two ways:
///   * **compile time**, on `Machine<From>`: use it wherever the code knows the state, such as
///     straight-line code or inside a `match` arm over the erased enum
///   * **run time**, on the erased enum: use it when the machine sits in a field, a map or
///     behind a lock. A call from a state without that transition returns the machine
///     unchanged together with an [`InvalidState`]. Owners that hold the machine in a field
///     can use [`transition_in_place`].
///
/// Why invalid compile-time calls cannot compile:
///   * a transition is an inherent method on `Machine<From>` only, so it does not
///     exist on any other state
///   * it takes `self` by value, so the old state is moved and cannot be reused
///   * the machine's fields are private to the module that invokes the macro, so code outside
///     that module cannot build a machine by hand
///
/// A transition name is declared once; list every source state with `|`. A transition body is
/// a block evaluating to the next state, so it must not use `return`.
#[macro_export]
macro_rules! typestate {
    (
        $(#[$mmeta:meta])*
        $vis:vis machine $machine:ident {
            shared: $shared:ty,
            erased: $(#[$ameta:meta])* $any:ident,
            states {
                $(
                    $(#[$smeta:meta])*
                    $state:ident as $alias:ident {
                        $( $fvis:vis $field:ident : $fty:ty ),* $(,)?
                    }
                )+
            }
            transitions { $($transitions:tt)* }
        }
    ) => {
        $(#[$mmeta])*
        #[must_use = "a transition returns the new state; dropping it drops the machine"]
        $vis struct $machine<S> {
            shared: $shared,
            state: S,
        }

        #[allow(dead_code)]
        impl<S> $machine<S> {
            /// Data that is available in every state.
            $vis fn shared(&self) -> &$shared { &self.shared }
            /// Mutable access to the data that is available in every state.
            $vis fn shared_mut(&mut self) -> &mut $shared { &mut self.shared }
            /// Data of the current state.
            $vis fn state(&self) -> &S { &self.state }
        }

        $(
            $(#[$smeta])*
            $vis struct $state { $( $fvis $field: $fty ),* }

            #[allow(dead_code)]
            $vis type $alias = $machine<$state>;

            impl From<$machine<$state>> for $any {
                fn from(m: $machine<$state>) -> Self { $any::$state(m) }
            }
        )+

        /// Every state behind one type, for collections and run-time dispatch.
        $(#[$ameta])*
        #[must_use = "a transition returns the new state; dropping it drops the machine"]
        $vis enum $any {
            $( $state($machine<$state>) ),+
        }

        #[allow(dead_code)]
        impl $any {
            $vis fn state_name(&self) -> &'static str {
                match self { $( $any::$state(_) => stringify!($state) ),+ }
            }
            $vis fn shared(&self) -> &$shared {
                match self { $( $any::$state(m) => &m.shared ),+ }
            }
            $vis fn shared_mut(&mut self) -> &mut $shared {
                match self { $( $any::$state(m) => &mut m.shared ),+ }
            }
        }

        $crate::typestate!(@transitions [$vis] $machine $any; $($transitions)*);
    };

    //  transition list: peel one transition off the front, then recurse
    (@transitions [$vis:vis] $machine:ident $any:ident;) => {};

    // A | B => C : fn name(shared, state, args...) { C { .. } }
    (@transitions [$vis:vis] $machine:ident $any:ident;
        $($from:ident)|+ => $to:ident :
        fn $name:ident $args:tt $body:block
        $($rest:tt)*
    ) => {
        $crate::typestate!(@each [$vis] $machine; [$($from)+] ($to) $name $args $body);
        $crate::typestate!(@erased [$vis] $any; [$($from)+] () $name $args);
        $crate::typestate!(@transitions [$vis] $machine $any; $($rest)*);
    };

    // A | B => Result<C, E> : fn name(shared, state, args...) { Ok(C { .. }) / Err((state, e)) }
    (@transitions [$vis:vis] $machine:ident $any:ident;
        $($from:ident)|+ => Result<$to:ident, $err:ty> :
        fn $name:ident $args:tt $body:block
        $($rest:tt)*
    ) => {
        $crate::typestate!(@each [$vis] $machine; [$($from)+] ($to, $err) $name $args $body);
        $crate::typestate!(@erased [$vis] $any; [$($from)+] ($err) $name $args);
        $crate::typestate!(@transitions [$vis] $machine $any; $($rest)*);
    };

    //  expand `A | B | C => X` into one impl per source state
    (@each [$vis:vis] $machine:ident; [] $ret:tt $name:ident $args:tt $body:block) => {};
    (@each [$vis:vis] $machine:ident;
        [$from:ident $($more:ident)*] $ret:tt $name:ident $args:tt $body:block
    ) => {
        $crate::typestate!(@impl [$vis] $machine; $from $ret $name $args $body);
        $crate::typestate!(@each [$vis] $machine; [$($more)*] $ret $name $args $body);
    };

    //  infallible transition
    (@impl [$vis:vis] $machine:ident; $from:ident ($to:ident) $name:ident
        ($shared:ident, $state:ident $(, $arg:ident : $aty:ty)* $(,)?) $body:block
    ) => {
        impl $machine<$from> {
            #[allow(unused_variables, unused_mut, dead_code)]
            $vis fn $name(self $(, $arg: $aty)*) -> $machine<$to> {
                let $machine { shared: mut common, state: mut $state } = self;
                let next: $to = { let $shared = &mut common; $body };
                $machine { shared: common, state: next }
            }
        }
    };

    //  fallible transition: on failure the caller gets the old state back
    (@impl [$vis:vis] $machine:ident; $from:ident ($to:ident, $err:ty) $name:ident
        ($shared:ident, $state:ident $(, $arg:ident : $aty:ty)* $(,)?) $body:block
    ) => {
        impl $machine<$from> {
            #[allow(unused_variables, unused_mut, dead_code)]
            $vis fn $name(self $(, $arg: $aty)*)
                -> ::core::result::Result<$machine<$to>, ($machine<$from>, $err)>
            {
                let $machine { shared: mut common, state: mut $state } = self;
                let outcome: ::core::result::Result<$to, ($from, $err)> =
                    { let $shared = &mut common; $body };
                match outcome {
                    Ok(next) => Ok($machine { shared: common, state: next }),
                    Err((prev, err)) => Err(($machine { shared: common, state: prev }, err)),
                }
            }
        }
    };

    //  run-time transition on the erased enum: split the argument list once, then collect one
    //  match arm per source state
    (@erased [$vis:vis] $any:ident; $from:tt $err:tt $name:ident
        ($shared:ident, $state:ident $(, $arg:ident : $aty:ty)* $(,)?)
    ) => {
        $crate::typestate!(
            @arms [$vis] $any; $from $err $name [$(, $arg: $aty)*] ($($arg),*) {}
        );
    };

    (@arms [$vis:vis] $any:ident; [$from:ident $($more:ident)*] () $name:ident
        $params:tt $call:tt { $($arms:tt)* }
    ) => {
        $crate::typestate!(@arms [$vis] $any; [$($more)*] () $name $params $call {
            $($arms)*
            $any::$from(machine) => Ok(machine.$name $call.into()),
        });
    };
    (@arms [$vis:vis] $any:ident; [$from:ident $($more:ident)*] ($err:ty) $name:ident
        $params:tt $call:tt { $($arms:tt)* }
    ) => {
        $crate::typestate!(@arms [$vis] $any; [$($more)*] ($err) $name $params $call {
            $($arms)*
            $any::$from(machine) => match machine.$name $call {
                Ok(next) => Ok(next.into()),
                Err((previous, error)) => Err((
                    previous.into(),
                    $crate::typestate::TransitionError::Failed(error),
                )),
            },
        });
    };

    (@arms [$vis:vis] $any:ident; [] () $name:ident
        [$($params:tt)*] $call:tt { $($arms:tt)* }
    ) => {
        #[allow(dead_code)]
        impl $any {
            /// Run-time checked form of the transition with the same name.
            #[allow(unreachable_patterns)]
            $vis fn $name(self $($params)*)
                -> ::core::result::Result<Self, (Self, $crate::typestate::InvalidState)>
            {
                match self {
                    $($arms)*
                    other => {
                        let invalid = $crate::typestate::InvalidState {
                            from: other.state_name(),
                            transition: stringify!($name),
                        };
                        Err((other, invalid))
                    }
                }
            }
        }
    };
    (@arms [$vis:vis] $any:ident; [] ($err:ty) $name:ident
        [$($params:tt)*] $call:tt { $($arms:tt)* }
    ) => {
        #[allow(dead_code)]
        impl $any {
            /// Run-time checked form of the transition with the same name.
            #[allow(unreachable_patterns)]
            $vis fn $name(self $($params)*) -> ::core::result::Result<
                Self,
                (Self, $crate::typestate::TransitionError<$err>),
            > {
                match self {
                    $($arms)*
                    other => {
                        let invalid = $crate::typestate::InvalidState {
                            from: other.state_name(),
                            transition: stringify!($name),
                        };
                        Err((other, invalid.into()))
                    }
                }
            }
        }
    };
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use assertions for failure reporting"
)]
mod tests {
    use super::{InvalidState, TransitionError, transition_in_place};

    crate::typestate! {
        #[derive(Debug)]
        machine Door {
            shared: u32,
            erased: #[derive(Debug)] AnyDoor,
            states {
                #[derive(Debug)]
                Open as OpenDoor {}
                #[derive(Debug)]
                Closed as ClosedDoor {}
                #[derive(Debug)]
                Locked as LockedDoor { pub code: u16 }
            }
            transitions {
                Open => Closed: fn close(uses, state) {
                    *uses += 1;
                    Closed {}
                }
                Closed | Locked => Open: fn open(uses, state) {
                    *uses += 1;
                    Open {}
                }
                Closed => Result<Locked, &'static str>: fn lock(uses, state, code: u16) {
                    if code == 0 {
                        Err((state, "empty code"))
                    } else {
                        Ok(Locked { code })
                    }
                }
            }
        }
    }

    fn door() -> OpenDoor {
        Door {
            shared: 0,
            state: Open {},
        }
    }

    #[test]
    fn typed_transitions_move_between_states() {
        let closed = door().close();
        let locked = closed.lock(7).unwrap();
        assert_eq!(locked.state().code, 7);
        let open = locked.open();
        assert_eq!(*open.shared(), 2);
    }

    #[test]
    fn runtime_transitions_follow_the_same_rules() {
        let any = AnyDoor::from(door());
        let any = any.close().unwrap();
        assert_eq!(any.state_name(), "Closed");
        let any = any.lock(7).unwrap();
        assert_eq!(any.state_name(), "Locked");
        let any = any.open().unwrap();
        assert_eq!((any.state_name(), *any.shared()), ("Open", 2));
    }

    #[test]
    fn runtime_transition_from_a_wrong_state_returns_the_machine() {
        let (any, invalid) = AnyDoor::from(door()).open().unwrap_err();
        assert_eq!(
            invalid,
            InvalidState {
                from: "Open",
                transition: "open"
            }
        );
        assert_eq!((any.state_name(), *any.shared()), ("Open", 0));

        let (any, error) = any.lock(7).unwrap_err();
        assert!(matches!(error, TransitionError::InvalidState(_)));
        assert_eq!(any.state_name(), "Open");
    }

    #[test]
    fn failed_transition_keeps_the_previous_state() {
        let (closed, error) = door().close().lock(0).unwrap_err();
        assert_eq!(error, "empty code");
        let (any, error) = AnyDoor::from(closed).lock(0).unwrap_err();
        assert_eq!(error, TransitionError::Failed("empty code"));
        assert_eq!(any.state_name(), "Closed");
    }

    #[test]
    fn in_place_transition_always_restores_the_slot() {
        let mut slot = Some(AnyDoor::from(door()));
        transition_in_place(&mut slot, AnyDoor::close).unwrap();
        let invalid: InvalidState = transition_in_place(&mut slot, AnyDoor::close).unwrap_err();
        assert_eq!(invalid.from, "Closed");
        let error = transition_in_place(&mut slot, |door| door.lock(0)).unwrap_err();
        assert_eq!(error, TransitionError::Failed("empty code"));
        assert_eq!(slot.as_ref().unwrap().state_name(), "Closed");

        let mut lost: Option<AnyDoor> = None;
        assert!(transition_in_place::<_, InvalidState>(&mut lost, AnyDoor::open).is_err());
    }
}
