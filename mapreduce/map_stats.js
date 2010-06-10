function(value, keyData, arg){
  function pad(n){return n<10 ? '0'+n : n}
  var date = new Date(Riak.mapValuesJson(value)[0] * 1000);
  var day = date.getUTCFullYear() + '-' +  pad(date.getUTCMonth() + 1) + '-' + pad(date.getUTCDate());
  var month = date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1);
  var year = date.getUTCFullYear().toString();
  var obj = {"count": 1};
  obj[day] = 1; 
  obj[month] = 1; 
  obj[year] = 1;
  return [obj]; // {"count":1,"2010-06-10":1,"2010-06":1,"2010":1}
}
