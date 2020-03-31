use log::{Log, Metadata, Record};

pub struct Logger;

impl Log for Logger {
    fn enabled(&self, _: &Metadata) -> bool {
        true
    }

    fn log(&self, record: &Record) {
        println!("{:>5} {}", record.level(), record.args());
    }

    fn flush(&self) {}
}
