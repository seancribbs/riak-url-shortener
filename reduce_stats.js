function(values, arg){
  var merged = {};
  values.forEach(function(value){
    for(var attr in value){
      if(merged[attr])
        merged[attr] += value[attr];
      else
        merged[attr] = value[attr];
    }
  });
  return [merged];
}
