var exec = require('cordova/exec');
module.exports = {
  /** The system picker, called on the main thread; answers { seconds, domain, code, description } when the completion block runs. */
  showPicker: function (success, failure) { exec(success, failure, 'NativeProbe', 'show', []); },
  /** The application delegate's window next to the key window. */
  state: function (success, failure) { exec(success, failure, 'NativeProbe', 'state', []); }
};
