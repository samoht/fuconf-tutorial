open OUnit
open G2048
open Board_utils

let mk_board_test = QCheck.mk_test ~n:1000 ~pp:string_of_board

let check_board_property name ?size (prop : board -> bool) =
  assert_equal true
    ~msg:(Printf.sprintf "QCheck test %s" name)
    QCheck.(run (mk_board_test ~name (arbitrary_board ?size) prop))

let check_full_board_property name ?size (prop : board -> bool) =
  assert_equal true
    ~msg:(Printf.sprintf "QCheck test %s" name)
    QCheck.(run (mk_board_test ~name (arbitrary_full_board ?size) prop))

let test_shift_board_fixpoint () =
  check_board_property "Shifting reaches a fixpoint after width(board) shifts"
    (fun board ->
      let fixed = iter (List.length board) (shift_board L) board in
      board_equal (shift_board L fixed) fixed)

let test_add_to_full () =
  check_full_board_property "Squares cannot be added to a fully-populated board"
    (fun board -> insert_square t2 board = None)

let test_add () =
  check_board_property "Squares can be added to a board with spaces"
    QCheck.(Prop.((fun board -> not (is_board_full board))
                  ==>
                  (fun board ->
                    insert_square t2 board <> None)))

(* Some tests for is_board_full *)
let test_is_board_full () =
  begin
    check_full_board_property "Randomly generated full boards are full"
      is_board_full;

    assert_equal true
      (is_board_full []);

    assert_equal true
      (is_board_full [[t2]]);

    assert_equal true
      (is_board_full [[t2; t4 ];
                      [t8; t16]]);

    assert_equal false
      (is_board_full [[empty]]);

    assert_equal false
      (is_board_full [[t2; empty];
                      [t4; t8   ]]);

    assert_equal false
      (is_board_full [[empty; empty];
                      [empty; empty]]);
  end

(* Some tests for is_board_winning *)
let test_is_board_winning () =
  begin
    assert_equal false
      ~msg:"An empty board is a winning board"
      (is_board_winning []);

    assert_equal true
      ~msg:"A 1x1 board containing 2048 is a winning board"
      (is_board_winning [[t2048]]);

    assert_equal true
      ~msg:"A shifted 1x1 board containing 2048 is a winning board"
      (is_board_winning (shift_board L [[t2048]]));

    assert_equal false
      ~msg:"A full 2x2 board without 2048 is not a winning board"
      (is_board_winning [[t2; t4 ];
                         [t8; t16]]);

    assert_equal true
      ~msg:"A full 2x2 board containing 2048 is a winning board"
      (is_board_winning [[t2048; t2 ];
                         [t8   ; t16]]);

    assert_equal true
      ~msg:"A partially-full 2x2 board containing 2048 is a winning board"
      (is_board_winning [[t2048; empty];
                         [t8   ; t16  ]]);

    assert_equal true
      ~msg:"A shifted partially-full 2x2 board containing 2048 is a winning board"
      (is_board_winning (shift_board L [[t2048; empty];
                                        [t8   ; t16  ]]));

    assert_equal false
      ~msg:"A 1x1 empty board is not a winning board"
      (is_board_winning [[empty]]);

    assert_equal false
      ~msg:"A 2x2 empty board is not a winning board"
      (is_board_winning [[empty; empty];
                         [empty; empty]]);
  end

let check_insert insert =
  let insert_property square board =
    let ofSome = function Some x -> x | None -> assert false in
   (* rely on the fact that `sort_squares` places empties first *)
    assert (not (is_board_full board));
    match insert square board with
    | Some board' -> 
       (sorted_squares (board_squares board')
        =
        sorted_squares (square :: List.tl (sorted_squares (board_squares board))))
    | None -> failwith "Insertion failed"
  in
  check_board_property "insert_into_board adds a square to the board"
    QCheck.(Prop.((fun board -> not (is_board_full board))
                     ==>
                  (insert_property t8)))

(* Tests for insert_square *)
let test_insert () = check_insert insert_square

(* Some tests for shifts *)
let test_shift_empty () =
  let empty_row = [[empty; empty; empty; empty]] in
  assert_equal empty_row
    ~msg:"Shifting an empty row leaves it unchanged"
    ~cmp:board_equal
    ~printer:string_of_board
    (shift_board L empty_row)

let test_shift_empty_squares () =
  let row = [[empty; t2; t4; empty]] in
  assert_equal [[t2; t4; empty; empty]]
    ~msg:"Shifting moves empty squares to the right (1)"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row);

  let row = [[t2; empty; empty; t4]] in
  assert_equal [[t2; t4; empty; empty]]
    ~msg:"Shifting moves empty squares to the right (2)"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row)

let test_shift_coalesce () =
  let row = [[t2; t2; empty; empty]] in
  assert_equal [[t4; empty; empty; empty]]
    ~msg:"Shifting coalesces adjacent equal tiles"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row);

  let row = [[t2; empty; empty; t2]] in
  assert_equal [[t4; empty; empty; empty]]
    ~msg:"Shifting coalesces equal tiles with empty squares between them"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row);

  let row = [[empty; t2; t2; t8]] in
  assert_equal [[t4; t8; empty; empty]]
    ~msg:"A single shift can move empties to the right and coalesce tiles"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row);

  let row = [[empty; t2; t2; t4]] in
  assert_equal [[t4; t4; empty; empty]]
    ~msg:"A single shift only coalesces tiles that are initially equal"
    ~cmp:board_equal
    ~printer:string_of_board
     (shift_board L row)

let test_shifts () =
  let board = [[t2   ; empty; t2   ; t4   ];
               [t2   ; empty; empty; t4   ];
               [empty; empty; empty; empty];
               [empty; empty; t8   ; t8   ]]
  in
  begin
    assert_equal
      [[t4   ; t4   ; empty; empty];
       [t2   ; t4   ; empty; empty];
       [empty; empty; empty; empty];
       [t16  ; empty; empty; empty]]
      ~msg:"left shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board L board);

    assert_equal
      [[empty; empty; t4   ; t4   ];
       [empty; empty; t2   ; t4   ];
       [empty; empty; empty; empty];
       [empty; empty; empty; t16  ]]
      ~msg:"right shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board R board);

    assert_equal
      [[t4   ; empty; t2   ; t8   ];
       [empty; empty; t8   ; t8   ];
       [empty; empty; empty; empty];
       [empty; empty; empty; empty]]
      ~msg:"up shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board U board);

    assert_equal
      [[empty; empty; empty; empty];
       [empty; empty; empty; empty];
       [empty; empty; t2   ; t8   ];
       [t4   ; empty; t8   ; t8   ]]
      ~msg:"down shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board D board);

    assert_equal
      [[t8   ; empty; empty; empty];
       [t2   ; t4   ; empty; empty];
       [empty; empty; empty; empty];
       [t16  ; empty; empty; empty]]
      ~msg:"double left shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board L (shift_board L board));

    assert_equal 
      [[t4   ; empty; t2   ; t16  ];
       [empty; empty; t8   ; empty];
       [empty; empty; empty; empty];
       [empty; empty; empty; empty]]
      ~msg:"double up shift 4x4 board"
      ~cmp:board_equal
      ~printer:string_of_board
      (shift_board U (shift_board U board));
  end

(* Some tests for provenance *)
let test_provenance () =
  let board = [[t2   ; empty; t2   ; t4   ];
               [t2   ; empty; empty; t4   ];
               [empty; empty; empty; empty];
               [empty; empty; t8   ; t8   ]]
  in
  let print_provenance_board b =
    "\n"^
    String.concat "\n"
      (List.map (fun row ->
        String.concat " "
          (List.map (fun provs ->
            match provs with
                [] -> "-"
              | provs -> String.concat "+"
                (List.map (fun {value; shift} -> Printf.sprintf "<-{%d}-%d" shift value) provs)) row)) b)
  in


  begin
    assert_equal
      ~printer:print_provenance_board
      [[[{value=2; shift=0}; {value=2; shift=2}]; [{value=4; shift=2}]; []; []];
       [[{value=2; shift=0}];                     [{value=4; shift=2}]; []; []];
       [[];                                       [];                   []; []];
       [[{value=8; shift=2}; {value=8; shift=3}]; [];                   []; []]]
      (board_provenance (shift_board L board));

    assert_equal
      ~printer:print_provenance_board
      [[[]; []; [{value=2; shift=0}; {value=2; shift=2}]; [{value=4; shift=0}]                    ];
       [[]; []; [{value=2; shift=2}];                     [{value=4; shift=0}]                    ];
       [[]; []; [];                                       []                                      ];
       [[]; []; [];                                       [{value=8; shift=0}; {value=8; shift=1}]]]
      (board_provenance (shift_board R board));

    assert_equal
      ~printer:print_provenance_board
      [[[{value=2; shift=0}; {value=2; shift=1}]; []; [{value=2; shift=0}]; [{value=4; shift=0}; {value=4; shift=1}]];
       [[];                                       []; [{value=8; shift=2}]; [{value=8; shift=2}]                    ];
       [[];                                       []; [];                   []                                      ];
       [[];                                       []; [];                   []                                      ]]
      (board_provenance (shift_board U board));

    assert_equal
      ~printer:print_provenance_board
      [[[];                                       []; [];                   []                                      ];
       [[];                                       []; [];                   []                                      ];
       [[];                                       []; [{value=2; shift=2}]; [{value=4; shift=1}; {value=4; shift=2}]];
       [[{value=2; shift=2}; {value=2; shift=3}]; []; [{value=8; shift=0}]; [{value=8; shift=0}]                    ]]
      (board_provenance (shift_board D board));
  end

(* Some tests for the game over condition *)
let test_game_over () =
  begin
    assert_equal true
      ~msg:"The game is over if the board is empty"
     (is_game_over
        []);

    assert_equal false
      ~msg:"The game is not over if there are empty squares"
     (is_game_over
        [[empty; t2  ; t8   ];
         [empty; t4  ; t16  ];
         [t1024; t512; t1024]]);

    assert_equal false
      ~msg:"The game is not over if there is an empty square on the edge"
     (is_game_over
        [[t8   ; t2  ; t8   ];
         [empty; t4  ; t16  ];
         [t1024; t512; t1024]]);

    assert_equal false
      ~msg:"The game is not over if there is an empty square in the centre"
     (is_game_over
        [[t8   ; t2   ; t8   ];
         [t16  ; empty; t16  ];
         [t1024; t512 ; t1024]]);

    assert_equal false
      ~msg:"The game is not over if there is a vertical tile-squashing move"
     (is_game_over
        [[t8   ; t2   ; t8   ];
         [t16  ; t512 ; t16  ];
         [t1024; t512 ; t1024]]);

    assert_equal false
      ~msg:"The game is not over if there is a horizontal tile-squashing move"
     (is_game_over
        [[t8   ; t2    ; t8   ];
         [t16  ; t8    ; t16  ];
         [t8   ; t1024 ; t1024]]);
  end

let suite = "2048 tests" >:::
  [
   (* 1. tests for is_board_winning *)
   test ~stage:1 "test is_board_winning"
    test_is_board_winning;

   (* 2. tests for shifts *)
   test ~stage:2 "test shifting empty rows"
    test_shift_empty;

   test ~stage:2 "test shifting moves empty squares to the right"
    test_shift_empty_squares;

   test ~stage:2 "test shifting can coalesce equal squares"
    test_shift_coalesce;

   test ~stage:2 "test shifts"
    test_shifts;

   test ~stage:2 "a fixpoint is reached after width(board) shift_boards"
    test_shift_board_fixpoint;

   (* 3. tests for insertions *)
   test ~stage:3 "squares can be added to a board that is not fully-populated"
    test_add;

   test ~stage:3 "squares cannot be added to a fully-populated board"
    test_add_to_full;

   test ~stage:3 "test insert_square"
    test_insert;

   (* 4. tests for is_game_over *)
   test ~stage:4 "test game over"
    test_game_over;

   (* 5. tests for provenance *) 
   test ~stage:5 "test provenance"
    test_provenance;

   (* Always-on tests *)
   test "test is_board_full"
    test_is_board_full;
  ]
let _ =
  run_test_tt_main suite
