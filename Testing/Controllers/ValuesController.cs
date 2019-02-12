using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Testing.Data;
using Testing.Models;

namespace Testing.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ValuesController : ControllerBase
    {
        private Value[] value;

        public ValuesController(DataContex data)
        {
            SetValue(data);
        }

        private async void SetValue(DataContex data)
        {
            value = await data.Values.ToArrayAsync();
        }

        // GET api/values
        [HttpGet]
        public IActionResult Get()
        {
            return Ok(value);
        }

        // GET api/values/5
        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id)
        {
            if (id <= value.Length)
                return await Task.Run(() => Ok(value[id - 1]));

            return Ok();
        }
        
        // POST api/values
        [HttpPost]
        public void Post([FromBody] string value)
        {
        }

        // PUT api/values/5
        [HttpPut("{id}")]
        public void Put(int id, [FromBody] string value)
        {
        }

        // DELETE api/values/5
        [HttpDelete("{id}")]
        public void Delete(int id)
        {
        }
    }
}
