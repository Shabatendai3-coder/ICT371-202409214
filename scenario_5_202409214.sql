-- SCENARIO 5: University Hostel Room Allocation
DROP TABLE IF EXISTS room_allocations;
DROP TABLE IF EXISTS hostel_rooms;

-- 1. CREATE TABLES
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20),
    available_beds INT
);

CREATE TABLE room_allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20),
    room_id INT REFERENCES hostel_rooms(room_id),
    num_beds INT,
    status VARCHAR(20) DEFAULT 'Allocated'
);

INSERT INTO hostel_rooms (room_number, available_beds) VALUES
('Block A-101', 4),
('Block A-102', 2),
('Block B-201', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE v_beds INT;
BEGIN
    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE room_id = 3;
    IF v_beds = 0 THEN
        RAISE NOTICE 'Room 3 is FULLY OCCUPIED';
    ELSIF v_beds < 2 THEN
        RAISE NOTICE 'Room 3 is ALMOST FULL: % beds left', v_beds;
    ELSE
        RAISE NOTICE 'Room 3 is AVAILABLE: % beds', v_beds;
    END IF;
END $$;

-- 3. WHILE and FOR loops
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- WHILE: Cleaning reminders ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Cleaning reminder %', i;
        i := i + 1;
    END LOOP;
    RAISE NOTICE '--- FOR: Room inspections ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Inspecting room %', i;
    END LOOP;
END $$;

-- 4. allocate_room PROCEDURE
CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid bed count: %', p_qty;
    END IF;
    SELECT available_beds INTO v_avail FROM hostel_rooms WHERE room_id = p_room_id;
    IF v_avail IS NULL THEN
        RAISE NOTICE 'Room % not found', p_room_id;
    ELSIF v_avail >= p_qty THEN
        UPDATE hostel_rooms SET available_beds = available_beds - p_qty WHERE room_id = p_room_id;
        INSERT INTO room_allocations(student_number, room_id, num_beds) VALUES(p_student, p_room_id, p_qty);
        RAISE NOTICE 'Allocated % bed(s) in room % for %', p_qty, p_room_id, p_student;
    ELSE
        RAISE NOTICE 'FAILED: Only % beds available in room %, requested %', v_avail, p_room_id, p_qty;
    END IF;
END $$;

-- 5. CALL 2 valid + 1 exceeding
CALL allocate_room('2023001', 1, 1);
CALL allocate_room('2023002', 1, 2);
CALL allocate_room('2023003', 2, 5); -- exceeds, only 2 left

SELECT * FROM hostel_rooms;
SELECT * FROM room_allocations;

-- 6. vacate_room PROCEDURE
CREATE OR REPLACE PROCEDURE vacate_room(p_allocation_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_room INT; v_qty INT;
BEGIN
    SELECT status, room_id, num_beds INTO v_status, v_room, v_qty FROM room_allocations WHERE allocation_id = p_allocation_id;
    IF v_status = 'Vacated' THEN
        RAISE NOTICE 'Allocation % already vacated, no beds restored', p_allocation_id;
    ELSE
        UPDATE room_allocations SET status = 'Vacated' WHERE allocation_id = p_allocation_id;
        UPDATE hostel_rooms SET available_beds = available_beds + v_qty WHERE room_id = v_room;
        RAISE NOTICE 'Allocation % vacated, % bed(s) restored to room %', p_allocation_id, v_qty, v_room;
    END IF;
END $$;

CALL vacate_room(1);
CALL vacate_room(1); -- second time no restore

-- 7. Explicit Cursor - low beds (FIXED VERSION - no error)
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '--- Rooms with few beds left ---';
    FOR rec IN SELECT room_id, room_number, available_beds FROM hostel_rooms WHERE available_beds < 3
    LOOP
        RAISE NOTICE 'Room % (%) has % bed(s) left', rec.room_id, rec.room_number, rec.available_beds;
    END LOOP;
END $$;

-- 8. EXCEPTION block - zero beds
DO $$
BEGIN
    CALL allocate_room('2023004', 1, 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- 9. Final Queries
SELECT * FROM hostel_rooms;
SELECT * FROM room_allocations;