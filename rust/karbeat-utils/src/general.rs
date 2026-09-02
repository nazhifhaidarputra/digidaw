
/// Move element from index i to index j
pub fn move_element<T>(slice: &mut [T], i: usize, j: usize) {
    if i == j {
        return;
    }
    if i < j {
        slice[i..=j].rotate_left(1);
    } else {
        slice[j..=i].rotate_right(1);
    }
}